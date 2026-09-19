import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import Context from "sap/ui/model/odata/v4/Context";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";
import MessageToast from "sap/m/MessageToast";
import MessageBox from "sap/m/MessageBox";
import ObjectStatus from "sap/m/ObjectStatus";
import JSONModel from "sap/ui/model/json/JSONModel";
import BusyIndicator from "sap/ui/core/BusyIndicator";
import DateFormat from "sap/ui/core/format/DateFormat";
import Dialog from "sap/m/Dialog";
import TextArea from "sap/m/TextArea";
import Button from "sap/m/Button";
import EventBus from "sap/ui/core/EventBus";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class RequestDetail extends Controller {
    private readonly ACTION_NAMESPACE = "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001";
    private readonly FIREFIGHTER_ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd/sap/zsd_iam_lifecycle/0001/FirefighterRole";
    private readonly CHANGE_GROUP_ID = "iamChanges";
    private _sReqUuid = "";
    private _eventBus!: EventBus;

    private _notifyRequestChanged(): void {
        this._eventBus.publish("hrm", "requestChanged", { ReqUuid: this._sReqUuid });
    }

    public onInit(): void {
        this._eventBus = (this.getOwnerComponent() as UIComponent).getEventBus();
        this.getView()?.setModel(new JSONModel({
            isEditing: false,
            canEdit: false,
            canSubmit: false,
            canApprove: false,
            canReject: false
        }), "edit");
        this.getView()?.setModel(new JSONModel({
            approvalReason: "",
            sodConflicts: [],
            isLoading: false,
            sodChecked: false,
            sodLoading: false
        }), "detail");
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteDetail")?.attachPatternMatched(this._onRouteMatched, this);
    }

    private _onRouteMatched(oEvent: Event): void {
        const oArgs = oEvent.getParameter("arguments") as any;
        this._sReqUuid = oArgs.ReqUuid;
        const oDetailModel = this.getView()?.getModel("detail") as JSONModel;
        oDetailModel?.setProperty("/approvalReason", "");
        oDetailModel?.setProperty("/sodConflicts", []);
        oDetailModel?.setProperty("/sodChecked", false);
        this._setEditing(false);
        this._setCanEdit(false);
        this._setActionAvailability(false, false, false);
        this._bindRequest(true);
    }

    private _bindRequest(bIsActiveEntity: boolean): void {
        const oView = this.getView();
        if (oView) {
            // Always start a fresh element binding. This is important when the
            // same list item is opened again after the detail view was closed;
            // otherwise UI5 can keep the previous context without requesting
            // the detail data a second time.
            (oView as unknown as { unbindElement: () => void }).unbindElement();
            oView.bindElement({
                path: `/Request(ReqUuid=${this._sReqUuid},IsActiveEntity=${bIsActiveEntity})`,
                parameters: {
                    $select: "ReqUuid,ReqId,ReqType,ReqTypeText,TargetUser,Title,FirstName,LastName,Department,Telephone,Mobile,Fax,Email,Status,StatusText,StatusCriticality,RiskScore,TicketId,Reason,DurationHours,FfGrantStatus,FfStartAt,FfEndAt,HasDraftEntity,HasActiveEntity,IsActiveEntity,__OperationControl,__EntityControl",
                    $$updateGroupId: this.CHANGE_GROUP_ID,
                    $$ownRequest: true
                },
                events: {
                    dataRequested: () => {
                        (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/isLoading", true);
                    },
                    dataReceived: () => {
                        (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/isLoading", false);
                        void this._updateDetailState();
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
                const oEditPromise = oAction.execute(this.CHANGE_GROUP_ID);
                await (oContext.getModel() as ODataModel).submitBatch(this.CHANGE_GROUP_ID);
                await oEditPromise;
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
            const oModel = oContext.getModel() as ODataModel;
            // Save persists the current draft only. Prepare/Activate is part
            // of Submit for Approval. Running those draft actions here also
            // makes an ordinary edit send an invalid DurationHours value
            // (empty text for non-Firefighter requests) and can leave RAP
            // waiting while a child role is still being updated.
            // Two-way OData bindings already queue edited fields in the
            // application update group; do not rewrite every control value.
            const sFirefighterError = await this._validateFirefighterEdit();
            if (sFirefighterError) {
                MessageBox.error(sFirefighterError, { title: "Invalid Firefighter duration" });
                return;
            }
            await oModel.submitBatch(this.CHANGE_GROUP_ID);
            this._setEditing(false);
            this._notifyRequestChanged();
            // Keep the draft binding after Save. Submit will perform
            // Prepare/Activate before sending the request for approval.
            this._bindRequest(false);
            MessageToast.show("Draft changes saved successfully.");
        } catch (err: any) {
            MessageBox.error("Save failed: " + this._getODataErrorMessage(err), {
                title: "Save Failed",
                details: err?.message || ""
            });
        } finally {
            BusyIndicator.hide();
        }
    }

    public async onCancelEdit(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        BusyIndicator.show(0);
        try {
            const oModel = oContext.getModel() as ODataModel;
            const oDiscardAction = oModel.bindContext(`${this.ACTION_NAMESPACE}.Discard(...)`, oContext) as any;
            const oDiscardPromise = oDiscardAction.execute(this.CHANGE_GROUP_ID);
            await oModel.submitBatch(this.CHANGE_GROUP_ID);
            await oDiscardPromise;
            this._setEditing(false);
            this._notifyRequestChanged();
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

    private _syncDraftFromControls(oContext: Context): void {
        const sReqType = (this.byId("editReqTypeSelect") as any)?.getSelectedKey?.() || "J";
        const sDuration = (this.byId("editDurationHoursInput") as any)?.getValue?.() || "";
        const iDuration = Number(sDuration);
        const mHeaderFields: Record<string, string | number> = {
            ReqType: sReqType,
            TargetUser: (this.byId("editTargetUserInput") as any)?.getValue?.() || "",
            Title: (this.byId("editTitleInput") as any)?.getValue?.() || "",
            FirstName: (this.byId("editFirstNameInput") as any)?.getValue?.() || "",
            LastName: (this.byId("editLastNameInput") as any)?.getValue?.() || "",
            Department: (this.byId("editDepartmentInput") as any)?.getValue?.() || "",
            Telephone: (this.byId("editTelephoneInput") as any)?.getValue?.() || "",
            Mobile: (this.byId("editMobileInput") as any)?.getValue?.() || "",
            Fax: (this.byId("editFaxInput") as any)?.getValue?.() || "",
            Email: (this.byId("editEmailInput") as any)?.getValue?.() || "",
            TicketId: (this.byId("editTicketIdInput") as any)?.getValue?.() || "",
            Reason: (this.byId("editReasonInput") as any)?.getValue?.() || "",
            // duration_hours is ABAP INT1 / OData Edm.Byte. Never send an
            // empty string for non-Firefighter requests.
            DurationHours: sReqType === "F" && Number.isInteger(iDuration) ? iDuration : 0
        };

        Object.entries(mHeaderFields).forEach(([sProperty, sValue]) => {
            this._queueProperty(oContext, sProperty, sValue);
        });

        const oRolesTable = this.byId("rolesTable") as any;
        (oRolesTable?.getItems?.() || []).forEach((oItem: any) => {
            const oRoleContext = oItem.getBindingContext() as Context;
            const aCells = oItem.getCells();
            const sRoleName = aCells[0]?.getItems?.()[1]?.getValue?.() || "";
            const sValidFrom = this._getDateValue(aCells[1]?.getItems?.()[1]);
            const sValidTo = this._getDateValue(aCells[2]?.getItems?.()[1]);

            this._queueProperty(oRoleContext, "RoleName", sRoleName);
            if (sValidFrom) {
                this._queueProperty(oRoleContext, "ValidFrom", sValidFrom);
            }
            if (sValidTo) {
                this._queueProperty(oRoleContext, "ValidTo", sValidTo);
            }
        });
    }

    private _queueProperty(oContext: any, sProperty: string, vValue: any): void {
        const oChange = oContext?.setProperty?.(sProperty, vValue);
        if (oChange && typeof oChange.catch === "function") {
            void oChange.catch(() => undefined);
        }
    }

    private _getDateValue(oDatePicker: any): string {
        const oDate = oDatePicker?.getDateValue?.();
        if (oDate instanceof Date) {
            return DateFormat.getDateInstance({ pattern: "yyyy-MM-dd" }).format(oDate, false);
        }

        return oDatePicker?.getValue?.() || "";
    }

    /**
     * Detail editing must apply the same allowlist max as the create wizard.
     * This is a UX check only; RAP Prepare/submit validation remains the
     * authoritative server-side check.
     */
    private async _validateFirefighterEdit(): Promise<string | undefined> {
        const sReqType = (this.byId("editReqTypeSelect") as any)?.getSelectedKey?.() || "J";
        if (sReqType !== "F") {
            return undefined;
        }

        const sDuration = String((this.byId("editDurationHoursInput") as any)?.getValue?.() || "").trim();
        const iDuration = Number(sDuration);
        if (!/^(?:[1-9]|1\d|2[0-4])$/.test(sDuration)) {
            return "Duration must be an integer from 1 to 24 hours.";
        }

        const oRolesTable = this.byId("rolesTable") as any;
        const aRoleNames = (oRolesTable?.getItems?.() || [])
            .map((oItem: any) => {
                const oRoleCell = oItem.getCells?.()[0];
                return String(oRoleCell?.getItems?.()[1]?.getValue?.()
                    || oRoleCell?.getItems?.()[0]?.getText?.() || "").trim();
            })
            .filter(Boolean);
        if (aRoleNames.length !== 1) {
            return "A Firefighter request must contain exactly one emergency role.";
        }

        const sRoleName = aRoleNames[0].replace(/'/g, "''");
        const sFilter = encodeURIComponent(`RoleName eq '${sRoleName}'`);
        const oResponse = await fetch(
            `${this.FIREFIGHTER_ROLE_VH_URL}?$top=1&$filter=${sFilter}&$format=json`,
            { credentials: "include", headers: { Accept: "application/json" } }
        );
        if (!oResponse.ok) {
            throw new Error(`Unable to load Firefighter role configuration (HTTP ${oResponse.status}).`);
        }
        const oData = await oResponse.json() as { value?: Array<{ MaxHours?: unknown }> };
        const oRole = oData.value?.[0];
        if (!oRole) {
            return "The selected emergency role is not active in the Firefighter allowlist.";
        }

        const iMaxHours = Number(oRole.MaxHours || 0);
        if (iMaxHours > 0 && iDuration > iMaxHours) {
            return `Duration exceeds the configured maximum of ${iMaxHours} hour(s) for role ${aRoleNames[0]}.`;
        }
        return undefined;
    }

    public onDeletePress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        oContext.delete().then(() => {
            MessageToast.show("Deleted successfully!");
            this._notifyRequestChanged();
            this.onCloseDetail();
        }).catch((err: Error) => MessageToast.show("Delete Error: " + err.message));
    }

    public async onSubmitPress(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        try {
            const oModel = oContext.getModel() as ODataModel;
            const bIsActiveEntity = await (oContext as any).requestProperty("IsActiveEntity");
            if (bIsActiveEntity === false) {
                // Run draft validations before the submit action. This closes
                // the path where an edited draft bypassed Step 1 validation.
                const oPrepareAction = oModel.bindContext(`${this.ACTION_NAMESPACE}.Prepare(...)`, oContext) as any;
                const oPreparePromise = oPrepareAction.execute(this.CHANGE_GROUP_ID);
                await Promise.all([oModel.submitBatch(this.CHANGE_GROUP_ID), oPreparePromise]);
            }

            const oAction = oModel.bindContext(`${this.ACTION_NAMESPACE}.submitForApproval(...)`, oContext) as any;
            await oAction.execute();
            MessageToast.show("Submitted successfully!");
            this._notifyRequestChanged();
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        } catch (err: any) {
            MessageToast.show("Submit Error: " + this._getODataErrorMessage(err));
        }
    }

    public async onApprovePress(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        let sApprovalReason = "";
        try {
            const iRiskScore = Number(await this._requestProperty(oContext, "RiskScore"));
            sApprovalReason = iRiskScore >= 3 ? (await this._requestApprovalReason() || "") : "";
            if (iRiskScore >= 3 && !sApprovalReason) {
                return;
            }
            await this._executeApprove(oContext, sApprovalReason);
            MessageToast.show("Approved successfully!");
            this._notifyRequestChanged();
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        } catch (err: any) {
            const sMessage = String(err.message || "Unknown error");
            if (!sApprovalReason && sMessage.toLowerCase().includes("rationale")) {
                const sRetryReason = await this._requestApprovalReason();
                if (sRetryReason) {
                    try {
                        await this._executeApprove(oContext, sRetryReason);
                        MessageToast.show("Approved successfully!");
                        this._notifyRequestChanged();
                        oContext.refresh();
                        setTimeout(() => this._updateDetailState(), 500);
                        return;
                    } catch (oRetryError: any) {
                        this._showApproveError(oRetryError);
                        return;
                    }
                }
            }
            this._showApproveError(err);
        }
    }

    public onRejectPress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.reject(...)`, oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Rejected successfully!");
            this._notifyRequestChanged();
            oContext.refresh();
            setTimeout(() => this._updateDetailState(), 500);
        }).catch((err: Error) => MessageToast.show("Reject Error: " + err.message));
    }

    public onCloseDetail(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }

    public async onShowApprovalRationale(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;
        try {
            const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.getApprovalRationale(...)`, oContext) as any;
            await oAction.execute();
            const oResult = await oAction.getBoundContext?.()?.requestObject?.();
            const sApprovalReason = String(oResult?.ApprovalReason || oResult?.value?.ApprovalReason || "");
            if (!sApprovalReason) {
                MessageToast.show("No approval rationale is available.");
                return;
            }
            (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/approvalReason", sApprovalReason);
        } catch (err: any) {
            MessageBox.error("Approval rationale is restricted to the approver or a Basis administrator.");
        }
    }

    public async onCheckSodPress(): Promise<void> {
        const oDetailModel = this.getView()?.getModel("detail") as JSONModel;
        oDetailModel?.setProperty("/sodLoading", true);
        try {
            await this._loadSodResult();
        } finally {
            oDetailModel?.setProperty("/sodLoading", false);
        }
    }

    private async _loadSodResult(): Promise<void> {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;
        try {
            const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.checkSod(...)`, oContext) as any;
            await oAction.execute();
            const oResult = await oAction.getBoundContext?.()?.requestObject?.();
            const aConflicts = oResult?.value || oResult?.Conflicts || [];
            (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/sodConflicts", aConflicts);
        } catch {
            (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/sodConflicts", []);
        } finally {
            (this.getView()?.getModel("detail") as JSONModel)?.setProperty("/sodChecked", true);
        }
    }

    private _requestApprovalReason(): Promise<string | null> {
        return new Promise((resolve) => {
            const oReasonInput = new TextArea({
                width: "100%",
                rows: 5,
                maxLength: 255,
                placeholder: "Explain why the Critical SoD conflict is approved. This rationale is audit logged."
            });
            const oDialog = new Dialog({
                title: "Critical SoD approval rationale",
                contentWidth: "32rem",
                content: [oReasonInput],
                beginButton: new Button({
                    text: "Approve",
                    type: "Accept",
                    press: () => {
                        const sReason = oReasonInput.getValue().trim();
                        if (!sReason) {
                            oReasonInput.setValueState("Error");
                            oReasonInput.setValueStateText("Approval rationale is required for Critical SoD.");
                            return;
                        }
                        oDialog.close();
                        resolve(sReason);
                    }
                }),
                endButton: new Button({
                    text: "Cancel",
                    press: () => {
                        oDialog.close();
                        resolve(null);
                    }
                }),
                afterClose: () => oDialog.destroy()
            });
            this.getView()?.addDependent(oDialog);
            oDialog.open();
        });
    }

    private async _executeApprove(oContext: Context, sApprovalReason: string): Promise<void> {
        const oAction = oContext.getModel().bindContext(`${this.ACTION_NAMESPACE}.approve(...)`, oContext) as any;
        // The OData action parameter is non-nullable in the service metadata.
        // Always send it; the RAP handler enforces non-empty rationale only for Critical SoD.
        oAction.setParameter("ApprovalReason", sApprovalReason || "");
        await oAction.execute();
    }

    /**
     * Uses the standard Fiori MessageBox details pattern.  The business summary
     * remains readable while the full OData/RAP message stays available through
     * the built-in "Show Details" link instead of being clipped in one line.
     */
    private _showApproveError(oError: unknown): void {
        const sDetails = this._getODataErrorMessage(oError);
        const bGrantInProgress = /firefighter grant.*(?:already|process)|grant.*already.*(?:pending|granting|active)/i.test(sDetails);
        const sSummary = bGrantInProgress
            ? "A Firefighter grant is already queued or being processed for this request."
            : "The approval could not be completed. Review the details and correct the request if needed.";

        MessageBox.error(sSummary, {
            title: "Approval Failed",
            details: sDetails
        });
    }

    private _getODataErrorMessage(oError: any): string {
        const aResponseTexts = [
            oError?.cause?.responseText,
            oError?.responseText,
            oError?.cause?.error?.responseText
        ];
        for (const sResponseText of aResponseTexts) {
            if (typeof sResponseText !== "string" || !sResponseText) {
                continue;
            }
            try {
                const oPayload = JSON.parse(sResponseText);
                const vMessage = oPayload?.error?.message?.value || oPayload?.error?.message;
                if (typeof vMessage === "string" && vMessage) {
                    return vMessage;
                }
            } catch (_parseError) {
                // Try the next OData error representation.
            }
        }
        const vMessage = oError?.error?.message || oError?.message;
        return typeof vMessage === "string" && vMessage
            ? vMessage
            : "No technical message was returned by the service.";
    }
}
