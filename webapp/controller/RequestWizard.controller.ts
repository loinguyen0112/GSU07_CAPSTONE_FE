import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";
import Context from "sap/ui/model/odata/v4/Context";
import ODataListBinding from "sap/ui/model/odata/v4/ODataListBinding";
import Event from "sap/ui/base/Event";
import Input from "sap/m/Input";
import WizardStep from "sap/m/WizardStep";
import MessageToast from "sap/m/MessageToast";
import MessageBox from "sap/m/MessageBox";
import Table from "sap/m/Table";
import JSONModel from "sap/ui/model/json/JSONModel";
import SelectDialog from "sap/m/SelectDialog";
import StandardListItem from "sap/m/StandardListItem";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";
import BusyIndicator from "sap/ui/core/BusyIndicator";
import DateFormat from "sap/ui/core/format/DateFormat";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class RequestWizard extends Controller {

    private _oDraftContext: Context | null = null;
    private _oDeptDialog: SelectDialog | null = null;
    private _oRoleDialog: SelectDialog | null = null;
    private _oRoleSourceInput: Input | null = null;
    private _oDeptModel: JSONModel | null = null;
    private _oRoleModel: JSONModel | null = null;
    private _oReviewModel: JSONModel | null = null;

    // F4 service base URLs (relative, proxied by fiori-tools-proxy) with proper session parameters
    private readonly DEPT_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_dept_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_lreq_hdr.department'/ZI_IAM_DEPT_VH";
    private readonly ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_role_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_req_role.rolename'/ZI_IAM_ROLE_VH";

    public onInit(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteWizard")?.attachPatternMatched(this._onRouteMatched, this);

        // Initialize JSON models for value help data
        this._oDeptModel = new JSONModel({ items: [] });
        this._oRoleModel = new JSONModel({ items: [] });
        this._oReviewModel = new JSONModel({
            request: this._getEmptyRequest(),
            roles: []
        });
        this.getView()?.setModel(this._oReviewModel, "review");
    }

    private _onRouteMatched(): void {
        this._oDraftContext = null;
        this._oReviewModel?.setProperty("/request", this._getEmptyRequest());
        this._oReviewModel?.setProperty("/roles", []);
    }

    public onUserInfoChange(): void {
        const targetUserInput = this.byId("targetUserInput") as Input;
        const emailInput = this.byId("emailInput") as Input;
        const step = this.byId("UserInfoStep") as WizardStep;

        if (targetUserInput.getValue() && emailInput.getValue()) {
            step.setValidated(true);
        } else {
            step.setValidated(false);
        }
    }

    public onAddRolePress(): void {
        const aRoles = this._getReviewRoles();
        aRoles.push({
            RoleName: "",
            ValidFrom: "",
            ValidTo: ""
        });
        this._oReviewModel?.setProperty("/roles", aRoles);
    }

    public onDeleteRole(oEvent: Event): void {
        const oButton = oEvent.getSource() as any;
        const oContext = oButton.getBindingContext("review");
        const sPath = oContext?.getPath?.();
        const iIndex = Number(sPath?.split("/").pop());
        const aRoles = this._getReviewRoles();

        if (!Number.isNaN(iIndex)) {
            aRoles.splice(iIndex, 1);
            this._oReviewModel?.setProperty("/roles", aRoles);
        }
    }

    public onWizardCompleted(): void {
        // Handle wizard completion if needed
    }

    public onReviewStepActivate(): void {
        this._syncRequestFromForm();
        this._syncRolePreviewFromTable();
    }

    public onRolePreviewChange(): void {
        this._syncRolePreviewFromTable();
    }

    private _syncRolePreviewFromTable(): void {
        const oTable = this.byId("roleTable") as Table;
        const aRoles = oTable.getItems().map((oItem: any) => {
            const aCells = oItem.getCells();

            return {
                RoleName: aCells[0]?.getValue?.() || "",
                ValidFrom: this._formatReviewDate(this._getDatePickerValue(aCells[1])),
                ValidTo: this._formatReviewDate(this._getDatePickerValue(aCells[2]))
            };
        }).filter((oRole) => oRole.RoleName || oRole.ValidFrom || oRole.ValidTo);

        this._oReviewModel?.setProperty("/roles", aRoles);
    }

    private _formatReviewDate(vDate: unknown): string {
        if (vDate instanceof Date) {
            return DateFormat.getDateInstance({ pattern: "yyyy-MM-dd" }).format(vDate, false);
        }

        if (typeof vDate !== "string" || !vDate) {
            return "";
        }

        if (/^\d{4}-\d{2}-\d{2}$/.test(vDate)) {
            return vDate;
        }

        const oParsedDate = DateFormat.getDateInstance({ pattern: "MMM dd, yyyy" }).parse(vDate, false, true);
        return oParsedDate instanceof Date
            ? DateFormat.getDateInstance({ pattern: "yyyy-MM-dd" }).format(oParsedDate, false)
            : "";
    }

    private _getDatePickerValue(oDatePicker: any): unknown {
        return oDatePicker?.getDateValue?.()
            || oDatePicker?.getValue?.()
            || oDatePicker?.getDomRef?.("inner")?.value
            || "";
    }

    private _syncRequestFromForm(): void {
        const oRequest = {
            ReqType: (this.byId("reqTypeSelect") as any)?.getSelectedKey?.() || "J",
            TargetUser: (this.byId("targetUserInput") as Input)?.getValue?.() || "",
            Email: (this.byId("emailInput") as Input)?.getValue?.() || "",
            FirstName: (this.byId("firstNameInput") as Input)?.getValue?.() || "",
            LastName: (this.byId("lastNameInput") as Input)?.getValue?.() || "",
            Department: (this.byId("departmentInput") as Input)?.getValue?.() || ""
        };

        this._oReviewModel?.setProperty("/request", oRequest);
    }

    public onSaveDraft(): void {
        BusyIndicator.show(0);
        const oModel = this.getView()?.getModel() as ODataModel;
        let oDraftCtx: Context;

        this._ensureDraftContext(oModel).then((oContext) => {
            oDraftCtx = oContext;
            return this._persistRoles(oModel, oDraftCtx);
        }).then(() => {
            const oPrepareAction = oModel.bindContext(
                "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.Prepare(...)",
                oDraftCtx
            ) as any;

            return oPrepareAction.execute();
        }).then(() => {
            const oActivateAction = oModel.bindContext(
                "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.Activate(...)",
                oDraftCtx
            ) as any;

            return oActivateAction.execute();
        }).then(() => {
            BusyIndicator.hide();
            MessageToast.show("Request saved successfully.");
            this._oDraftContext = null;
            this.onNavBack();
        }).catch((err: any) => {
            BusyIndicator.hide();
            MessageBox.error("Save failed: " + (err.message || "Unknown error"));
        });
    }

    public onSubmitApproval(): void {
        BusyIndicator.show(0);
        const oModel = this.getView()?.getModel() as ODataModel;
        let oDraftCtx: Context;

        this._ensureDraftContext(oModel).then((oContext) => {
            oDraftCtx = oContext;
            return this._persistRoles(oModel, oDraftCtx);
        }).then(() => {
            // Step 1: Prepare — triggers server-side validations (validateEmail, etc.)
            const oPrepareAction = oModel.bindContext(
                "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.Prepare(...)",
                oDraftCtx
            ) as any;

            return oPrepareAction.execute();
        }).then(() => {
            // Step 2: Activate — converts draft to active entity
            const oActivateAction = oModel.bindContext(
                "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.Activate(...)",
                oDraftCtx
            ) as any;

            return oActivateAction.execute();
        }).then(() => {
            // Step 3: submitForApproval
            // Must use absolute path to avoid "Nested deferred operation bindings not supported" error.
            // After Activate, the entity is active — build canonical path with IsActiveEntity=true.
            const sReqUuid = (oDraftCtx as any).getProperty("ReqUuid");
            const sActivePath = `/Request(ReqUuid=${sReqUuid},IsActiveEntity=true)`;

            const oActiveBinding = oModel.bindContext(
                `${sActivePath}/com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.submitForApproval(...)`
            ) as any;

            return oActiveBinding.execute();
        }).then(() => {
            BusyIndicator.hide();
            MessageToast.show("Request submitted for approval successfully!");
            this._oDraftContext = null;
            this.onNavBack();
        }).catch((err: any) => {
            BusyIndicator.hide();
            MessageBox.error("Submit failed: " + (err.message || "Unknown error"));
        });
    }

    private async _persistRoles(oModel: ODataModel, oDraftCtx: Context): Promise<void> {
        this._syncRolePreviewFromTable();
        const oCreatedPromise = (oDraftCtx as any).created?.();
        if (oCreatedPromise) {
            await oCreatedPromise;
        }

        const sDraftPath = oDraftCtx.getPath();
        if (!sDraftPath || sDraftPath.includes("$uid")) {
            throw new Error("Draft request is not ready for role assignment.");
        }

        const aRoles = this._getReviewRoles()
            .filter((oRole) => oRole.RoleName)
            .map((oRole) => ({
                RoleName: oRole.RoleName,
                ValidFrom: oRole.ValidFrom || null,
                ValidTo: oRole.ValidTo || null
            }));

        const oRoleBinding = oModel.bindList(`${sDraftPath}/_Roles`) as ODataListBinding;
        await Promise.all(aRoles.map((oRole) => {
            const oRoleContext = oRoleBinding.create(oRole, true);
            const oRoleCreated = (oRoleContext as any).created?.();

            return oRoleCreated || Promise.resolve();
        }));
    }

    private _getReviewRoles(): Array<{ RoleName: string; ValidFrom: string; ValidTo: string }> {
        return [...(this._oReviewModel?.getProperty("/roles") || [])] as Array<{ RoleName: string; ValidFrom: string; ValidTo: string }>;
    }

    private _getEmptyRequest(): Record<string, string> {
        return {
            TargetUser: "",
            Email: "",
            FirstName: "",
            LastName: "",
            Department: "",
            ReqType: "J"
        };
    }

    private async _ensureDraftContext(oModel: ODataModel): Promise<Context> {
        if (this._oDraftContext) {
            return this._oDraftContext;
        }

        this._syncRequestFromForm();
        const oRequest = this._oReviewModel?.getProperty("/request") as Record<string, string>;
        if (!oRequest?.TargetUser || !oRequest?.Email) {
            throw new Error("Employee ID and email are required.");
        }

        const oListBinding = oModel.bindList("/Request") as ODataListBinding;
        this._oDraftContext = oListBinding.create({ ...oRequest }, true);
        const oCreatedPromise = (this._oDraftContext as any).created?.();
        if (oCreatedPromise) {
            await oCreatedPromise;
        }

        return this._oDraftContext;
    }

    // ======================= Value Help: Department =======================

    public onDepartmentVHRequest(): void {
        if (!this._oDeptDialog) {
            this._oDeptDialog = new SelectDialog({
                title: "Select Department",
                noDataText: "No departments found",
                items: {
                    path: "deptVH>/items",
                    template: new StandardListItem({
                        title: "{deptVH>DepartmentID}",
                        description: "{deptVH>DepartmentName}"
                    })
                },
                search: (oEvent: Event) => { this._onDeptDialogSearch(oEvent); },
                confirm: (oEvent: Event) => { this._onDeptDialogConfirm(oEvent); },
                cancel: () => { /* dialog closed */ }
            });
            this.getView()?.addDependent(this._oDeptDialog);
            this._oDeptDialog.setModel(this._oDeptModel as JSONModel, "deptVH");
        }

        // Load department data from F4 service
        this._loadDeptData();
        this._oDeptDialog.open("");
    }

    private _loadDeptData(sFilter?: string): void {
        let sUrl = this.DEPT_VH_URL + "?$top=200&$format=json";
        if (sFilter) {
            sUrl += "&$filter=contains(DepartmentName,'" + encodeURIComponent(sFilter) + "') or contains(DepartmentID,'" + encodeURIComponent(sFilter) + "')";
        }

        fetch(sUrl, {
            credentials: "include",
            headers: { "Accept": "application/json" }
        })
        .then(response => response.json())
        .then((data: any) => {
            this._oDeptModel?.setProperty("/items", data.value || []);
        })
        .catch(() => {
            MessageToast.show("Failed to load departments.");
        });
    }

    private _onDeptDialogSearch(oEvent: Event): void {
        const sValue = oEvent.getParameter("value") as string;
        this._loadDeptData(sValue);
    }

    private _onDeptDialogConfirm(oEvent: Event): void {
        const oSelectedItem = oEvent.getParameter("selectedItem") as any;
        if (oSelectedItem) {
            const oBindingCtx = oSelectedItem.getBindingContext("deptVH");
            const sDeptId = oBindingCtx.getProperty("DepartmentID");
            // Set the Department value on the draft context
            const oDepartmentInput = this.byId("departmentInput") as Input;
            if (oDepartmentInput) {
                oDepartmentInput.setValue(sDeptId);
            }
            this._oReviewModel?.setProperty("/request/Department", sDeptId);
        }
    }

    // ======================= Value Help: Role =======================

    public onRoleVHRequest(oEvent: Event): void {
        // Store the source input so we know which row to update
        this._oRoleSourceInput = oEvent.getSource() as Input;

        if (!this._oRoleDialog) {
            this._oRoleDialog = new SelectDialog({
                title: "Select Role",
                noDataText: "No roles found",
                items: {
                    path: "roleVH>/items",
                    template: new StandardListItem({
                        title: "{roleVH>RoleName}",
                        description: "{roleVH>Description}"
                    })
                },
                search: (oEvt: Event) => { this._onRoleDialogSearch(oEvt); },
                confirm: (oEvt: Event) => { this._onRoleDialogConfirm(oEvt); },
                cancel: () => { /* dialog closed */ }
            });
            this.getView()?.addDependent(this._oRoleDialog);
            this._oRoleDialog.setModel(this._oRoleModel as JSONModel, "roleVH");
        }

        // Load role data from F4 service
        this._loadRoleData();
        this._oRoleDialog.open("");
    }

    private _loadRoleData(sSearch?: string): void {
        let sUrl = this.ROLE_VH_URL + "?$top=200&$format=json";
        if (sSearch) {
            // Role VH supports $search
            sUrl += "&$search=" + encodeURIComponent(sSearch);
        }

        fetch(sUrl, {
            credentials: "include",
            headers: { "Accept": "application/json" }
        })
        .then(response => response.json())
        .then((data: any) => {
            this._oRoleModel?.setProperty("/items", data.value || []);
        })
        .catch(() => {
            MessageToast.show("Failed to load roles.");
        });
    }

    private _onRoleDialogSearch(oEvent: Event): void {
        const sValue = oEvent.getParameter("value") as string;
        this._loadRoleData(sValue);
    }

    private _onRoleDialogConfirm(oEvent: Event): void {
        const oSelectedItem = oEvent.getParameter("selectedItem") as any;
        if (oSelectedItem && this._oRoleSourceInput) {
            const oBindingCtx = oSelectedItem.getBindingContext("roleVH");
            const sRoleName = oBindingCtx.getProperty("RoleName");
            // Set value on the Input control (triggers two-way binding to OData model)
            this._oRoleSourceInput.setValue(sRoleName);
            // Also set on the OData binding context
            const oRowContext = this._oRoleSourceInput.getBindingContext("review") as any;
            if (oRowContext) {
                oRowContext.setProperty("RoleName", sRoleName);
            }
        }
    }

    // ======================= Navigation =======================

    public onNavBack(): void {
        // Discard draft if navigating back without submitting
        if (this._oDraftContext) {
            this._oDraftContext.delete().catch(() => {
                // Silently ignore — draft may already be discarded
            });
            this._oDraftContext = null;
        }
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }
}
