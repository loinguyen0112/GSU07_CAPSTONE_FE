import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import Context from "sap/ui/model/odata/v4/Context";
import MessageToast from "sap/m/MessageToast";
import MessageBox from "sap/m/MessageBox";
import ObjectStatus from "sap/m/ObjectStatus";
import JSONModel from "sap/ui/model/json/JSONModel";
import BusyIndicator from "sap/ui/core/BusyIndicator";
import DateFormat from "sap/ui/core/format/DateFormat";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class RequestDetail extends Controller {
    private readonly ACTION_NAMESPACE = "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001";
    private _sReqUuid = "";

    public onInit(): void {
        this.getView()?.setModel(new JSONModel({
            isEditing: false,
            canEdit: false,
            canSubmit: false,
            canApprove: false,
            canReject: false
        }), "edit");
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteDetail")?.attachPatternMatched(this._onRouteMatched, this);
    }

    private _onRouteMatched(oEvent: Event): void {
        const oArgs = oEvent.getParameter("arguments") as any;
        this._sReqUuid = oArgs.ReqUuid;
        this._setEditing(false);
        this._setCanEdit(false);
        this._setActionAvailability(false, false, false);
        this._bindRequest(true);
    }

    private _bindRequest(bIsActiveEntity: boolean): void {
        const oView = this.getView();
        if (oView) {
            oView.bindElement({
                path: `/Request(ReqUuid=${this._sReqUuid},IsActiveEntity=${bIsActiveEntity})`,
                parameters: {
                    $select: "ReqUuid,ReqId,ReqType,ReqTypeText,TargetUser,Title,FirstName,LastName,Department,Telephone,Mobile,Fax,Email,Status,StatusText,StatusCriticality,RiskScore,HasDraftEntity,HasActiveEntity,IsActiveEntity,__OperationControl,__EntityControl",
                    $$ownRequest: true
                },
                events: {
                    dataReceived: () => {
                        // Use setTimeout to ensure context data is available
                        setTimeout(() => this._updateDetailState(), 100);
                    }
                }
            });
        }
    }

    private _setEditing(bIsEditing: boolean): void {
        (this.getView()?.getModel("edit") as JSONModel)?.setProperty("/isEditing", bIsEditing);
    }

    private _setCanEdit(bCanEdit: boolean): void {
        (this.getView()?.getModel("edit") as JSONModel)?.setProperty("/canEdit", bCanEdit);
    }

    private _setActionAvailability(bCanSubmit: boolean, bCanApprove: boolean, bCanReject: boolean): void {
        const oEditModel = this.getView()?.getModel("edit") as JSONModel;
        oEditModel?.setProperty("/canSubmit", bCanSubmit);
        oEditModel?.setProperty("/canApprove", bCanApprove);
        oEditModel?.setProperty("/canReject", bCanReject);
    }

    private async _updateDetailState(): Promise<void> {
        const oContext = this.getView()?.getBindingContext();
        if (!oContext) return;

        try {
            const [sStatus, sStatusText, oOperationControl] = await Promise.all([
                this._requestProperty(oContext as Context, "Status"),
                this._requestProperty(oContext as Context, "StatusText"),
                this._requestProperty(oContext as Context, "__OperationControl")
            ]);

            const bIsDraft = this._isBusinessDraft(sStatus, sStatusText);
            const bIsSubmitted = sStatus === "02" || (sStatusText || "").toLowerCase() === "submitted";

            this._setCanEdit(bIsDraft);
            this._setActionAvailability(
                bIsDraft && oOperationControl?.submitForApproval === true,
                bIsSubmitted && oOperationControl?.approve === true,
                bIsSubmitted && oOperationControl?.reject === true
            );
        } catch {
            this._setCanEdit(false);
            this._setActionAvailability(false, false, false);
        }

        (oContext as any).requestProperty("StatusCriticality").then((iCriticality: number) => {
            // Update status criticality color
            const oHeaderStatus = this.byId("headerStatus") as ObjectStatus;
            const oPersonStatus = this.byId("personStatus") as ObjectStatus;
            let sState = "None";
            if (iCriticality === 1) sState = "Error";
            else if (iCriticality === 2) sState = "Warning";
            else if (iCriticality === 3) sState = "Success";

            if (oHeaderStatus) oHeaderStatus.setState(sState as any);
            if (oPersonStatus) oPersonStatus.setState(sState as any);
        }).catch(() => {
            // Silently handle - properties may not be available yet
        });
    }

    private async _requestProperty(oContext: Context, sPath: string): Promise<any> {
        const vLocalValue = (oContext as any).getObject?.(sPath);
        if (vLocalValue !== undefined) {
            return vLocalValue;
        }

        return (oContext as any).requestProperty(sPath);
    }

    public async onEditPress(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        BusyIndicator.show(0);
        try {
            const [sStatus, sStatusText] = await Promise.all([
                (oContext as any).requestProperty("Status"),
                (oContext as any).requestProperty("StatusText")
            ]);
            if (!this._isBusinessDraft(sStatus, sStatusText)) {
                MessageBox.warning("Only Draft requests can be edited.");
                return;
            }

            const bHasDraft = await (oContext as any).requestProperty("HasDraftEntity");
            if (!bHasDraft) {
                const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.Edit(...)`, oContext) as any;
                oAction.setParameter("PreserveChanges", true);
                await oAction.execute();
            }

            this._bindRequest(false);
            this._setEditing(true);
            MessageToast.show(bHasDraft ? "Existing draft opened for editing." : "Edit mode enabled.");
        } catch (err: any) {
            MessageBox.error("Edit failed: " + (err.message || "Unknown error"));
        } finally {
            BusyIndicator.hide();
        }
    }

    private _isBusinessDraft(sStatus?: string, sStatusText?: string): boolean {
        return sStatus === "01" || (sStatusText || "").toLowerCase() === "draft";
    }

    public async onSaveEdit(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        BusyIndicator.show(0);
        try {
            const oModel = oContext.getModel();
            await this._syncDraftFromControls(oContext);

            const oPrepareAction = oModel.bindContext(`${this.ACTION_NAMESPACE}.Prepare(...)`, oContext) as any;
            await oPrepareAction.execute();

            const oActivateAction = oModel.bindContext(`${this.ACTION_NAMESPACE}.Activate(...)`, oContext) as any;
            await oActivateAction.execute();

            this._setEditing(false);
            this._bindRequest(true);
            MessageToast.show("Changes saved successfully.");
        } catch (err: any) {
            MessageBox.error("Save failed: " + (err.message || "Unknown error"));
        } finally {
            BusyIndicator.hide();
        }
    }

    public async onCancelEdit(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        BusyIndicator.show(0);
        try {
            const oDiscardAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.Discard(...)`, oContext) as any;
            await oDiscardAction.execute();
            this._setEditing(false);
            this._bindRequest(true);
            MessageToast.show("Changes discarded.");
        } catch (err: any) {
            MessageBox.error("Cancel failed: " + (err.message || "Unknown error"));
        } finally {
            BusyIndicator.hide();
        }
    }

    public onDeleteRolePress(oEvent: Event): void {
        const oRoleContext = (oEvent.getSource() as any).getBindingContext() as Context;
        oRoleContext?.delete().catch((err: Error) => MessageToast.show("Delete Role Error: " + err.message));
    }

    private async _syncDraftFromControls(oContext: Context): Promise<void> {
        const mHeaderFields: Record<string, string> = {
            ReqType: (this.byId("editReqTypeSelect") as any)?.getSelectedKey?.() || "J",
            TargetUser: (this.byId("editTargetUserInput") as any)?.getValue?.() || "",
            Title: (this.byId("editTitleInput") as any)?.getValue?.() || "",
            FirstName: (this.byId("editFirstNameInput") as any)?.getValue?.() || "",
            LastName: (this.byId("editLastNameInput") as any)?.getValue?.() || "",
            Department: (this.byId("editDepartmentInput") as any)?.getValue?.() || "",
            Telephone: (this.byId("editTelephoneInput") as any)?.getValue?.() || "",
            Mobile: (this.byId("editMobileInput") as any)?.getValue?.() || "",
            Fax: (this.byId("editFaxInput") as any)?.getValue?.() || "",
            Email: (this.byId("editEmailInput") as any)?.getValue?.() || ""
        };

        await Promise.all(Object.entries(mHeaderFields).map(([sProperty, sValue]) =>
            (oContext as any).setProperty(sProperty, sValue)
        ));

        const oRolesTable = this.byId("rolesTable") as any;
        const aRoleUpdates = (oRolesTable?.getItems?.() || []).flatMap((oItem: any) => {
            const oRoleContext = oItem.getBindingContext() as Context;
            const aCells = oItem.getCells();
            const sRoleName = aCells[0]?.getItems?.()[1]?.getValue?.() || "";
            const sValidFrom = this._getDateValue(aCells[1]?.getItems?.()[1]);
            const sValidTo = this._getDateValue(aCells[2]?.getItems?.()[1]);

            return [
                (oRoleContext as any).setProperty("RoleName", sRoleName),
                (oRoleContext as any).setProperty("ValidFrom", sValidFrom || null),
                (oRoleContext as any).setProperty("ValidTo", sValidTo || null)
            ];
        });

        await Promise.all(aRoleUpdates);
    }

    private _getDateValue(oDatePicker: any): string {
        const oDate = oDatePicker?.getDateValue?.();
        if (oDate instanceof Date) {
            return DateFormat.getDateInstance({ pattern: "yyyy-MM-dd" }).format(oDate, false);
        }

        return oDatePicker?.getValue?.() || "";
    }

    public onDeletePress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        oContext.delete().then(() => {
            MessageToast.show("Deleted successfully!");
            this.onCloseDetail();
        }).catch((err: Error) => MessageToast.show("Delete Error: " + err.message));
    }

    public onSubmitPress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.submitForApproval(...)`, oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Submitted successfully!");
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        }).catch((err: Error) => MessageToast.show("Submit Error: " + err.message));
    }

    public onApprovePress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.approve(...)`, oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Approved successfully!");
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        }).catch((err: Error) => MessageToast.show("Approve Error: " + err.message));
    }

    public onRejectPress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.reject(...)`, oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Rejected successfully!");
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        }).catch((err: Error) => MessageToast.show("Reject Error: " + err.message));
    }

    public onCloseDetail(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }
}
