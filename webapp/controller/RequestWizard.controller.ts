import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";
import Context from "sap/ui/model/odata/v4/Context";
import ODataListBinding from "sap/ui/model/odata/v4/ODataListBinding";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";
import Event from "sap/ui/base/Event";
import Input from "sap/m/Input";
import WizardStep from "sap/m/WizardStep";
import MessageToast from "sap/m/MessageToast";
import MessageBox from "sap/m/MessageBox";
import Table from "sap/m/Table";
import Dialog from "sap/m/Dialog";
import Button from "sap/m/Button";
import Column from "sap/m/Column";
import ColumnListItem from "sap/m/ColumnListItem";
import ObjectStatus from "sap/m/ObjectStatus";
import Text from "sap/m/Text";
import VBox from "sap/m/VBox";
import Title from "sap/m/Title";
import MessageStrip from "sap/m/MessageStrip";
import JSONModel from "sap/ui/model/json/JSONModel";
import SelectDialog from "sap/m/SelectDialog";
import StandardListItem from "sap/m/StandardListItem";
import BusyIndicator from "sap/ui/core/BusyIndicator";
import BusyDialog from "sap/m/BusyDialog";
import DateFormat from "sap/ui/core/format/DateFormat";

type RequestRole = {
    RoleName: string;
    ValidFrom: string;
    ValidTo: string;
    MaxHours?: number;
};

type RequestData = Record<string, string | number>;

type SodConflict = {
    RuleId: string;
    RuleName: string;
    Role1: string;
    Role2: string;
    RiskLevel: string;
    IsExempt: boolean;
    ExemptReason: string;
    SuggestedAction: string;
    IsLocked: boolean;
    LastLogin: string;
};

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
    private _oSubmitBusyDialog: BusyDialog | null = null;
    private _sodCheckInFlight: Promise<{ hasCritical: boolean }> | null = null;
    private _lastPersistedRequestPayload = "";
    private _lastPersistedRolePayload = "";
    private _hasPersistedRoleItems = false;

    private readonly DEPT_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_dept_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_lreq_hdr.department'/ZI_IAM_DEPT_VH";
    private readonly ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_role_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_req_role.rolename'/ZI_IAM_ROLE_VH";
    private readonly FIREFIGHTER_ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd/sap/zsd_iam_lifecycle/0001/FirefighterRole";
    private readonly SERVICE_NAMESPACE = "com.sap.gateway.srvd.zsd_iam_lifecycle.v0001";
    private readonly CHANGE_GROUP_ID = "iamChanges";
    private readonly SUBMIT_TIMEOUT_MS = 45000;

    public onInit(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteWizard")?.attachPatternMatched(this._onRouteMatched, this);
        this._oDeptModel = new JSONModel({ items: [] });
        this._oRoleModel = new JSONModel({ items: [] });
        this._oReviewModel = new JSONModel(this._getReviewData());
        this.getView()?.setModel(this._oReviewModel, "review");
    }

    private _onRouteMatched(): void {
        // A route re-entry can occur after browser navigation while an RAP
        // draft still exists. Discard it asynchronously before starting a
        // fresh request; otherwise every test/check leaves a server draft.
        void this._discardOpenDraft();
        this._resetDraftTracking();
        this._oReviewModel?.setData(this._getReviewData());
    }

    public onUserInfoChange(): void {
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType") || "J");
        const oTargetUserInput = (sReqType === "L"
            ? this.byId("leaverTargetUserInput")
            : this.byId("targetUserInput")) as Input;
        const oEmailInput = this.byId("emailInput") as Input;
        const oDepartmentInput = this.byId("departmentInput") as Input;
        const oStep = this.byId("UserInfoStep") as WizardStep;
        const bTargetUserValid = Boolean(oTargetUserInput.getValue().trim());
        this._setFieldValidity(oTargetUserInput, bTargetUserValid, "SAP user is required.");

        if (sReqType === "F") {
            const oTicketInput = this.byId("ticketIdInput") as Input;
            const oReasonInput = this.byId("reasonInput") as any;
            const oDurationInput = this.byId("durationHoursInput") as Input;
            const bTicketValid = Boolean(oTicketInput.getValue().trim());
            const bReasonValid = Boolean(oReasonInput.getValue().trim());
            const sDuration = oDurationInput.getValue().trim();
            const iDuration = Number(sDuration);
            const iRoleMaxHours = Number(this._getReviewRoles()[0]?.MaxHours || 0);
            const bDurationValid = /^(?:[1-9]|1\d|2[0-4])$/.test(sDuration)
                && (!iRoleMaxHours || iDuration <= iRoleMaxHours);
            const sDurationMessage = iRoleMaxHours
                ? `Duration must be a whole number from 1 to ${Math.min(24, iRoleMaxHours)} hours for the selected role.`
                : "Duration must be a whole number from 1 to 24 hours.";
            this._setFieldValidity(oTicketInput, bTicketValid, "Emergency ticket ID is required.");
            this._setFieldValidity(oReasonInput, bReasonValid, "Emergency reason is required.");
            this._setFieldValidity(oDurationInput, bDurationValid, sDurationMessage);
            oStep.setValidated(bTargetUserValid && bTicketValid && bReasonValid && bDurationValid);
        } else if (sReqType === "M") {
            const bDepartmentValid = Boolean(oDepartmentInput.getValue().trim());
            this._setFieldValidity(oEmailInput, true, "");
            this._setFieldValidity(oDepartmentInput, bDepartmentValid, "New department is required for a Mover request.");
            oStep.setValidated(bTargetUserValid && bDepartmentValid);
        } else if (sReqType === "L") {
            this._setFieldValidity(oEmailInput, true, "");
            this._setFieldValidity(oDepartmentInput, true, "");
            oStep.setValidated(bTargetUserValid);
        } else {
            const bEmailValid = this._isEmailValid(oEmailInput.getValue());
            this._setFieldValidity(oEmailInput, bEmailValid, "Enter a valid email address.");
            this._setFieldValidity(oDepartmentInput, true, "");
            oStep.setValidated(bTargetUserValid && bEmailValid);
        }
        this._invalidateSodResult();
    }

    public onRequestTypeChange(oEvent: Event): void {
        // Keep the JSON model in sync before deciding which Wizard steps exist.
        // WizardStep has no `visible` property; a Leaver must therefore have its
        // role step removed from the Wizard aggregation altogether.
        const sReqType = String((oEvent.getSource() as any)?.getSelectedKey?.()
            || this._oReviewModel?.getProperty("/request/ReqType") || "J");
        this._oReviewModel?.setProperty("/request/ReqType", sReqType);
        this._oReviewModel?.setProperty("/leaverStep", 1);
        const aRoles = this._getReviewRoles();
        if (sReqType === "L") {
            this._oReviewModel?.setProperty("/roles", []);
        } else if (sReqType === "F" && aRoles.length > 1) {
            this._oReviewModel?.setProperty("/roles", [{
                RoleName: aRoles[0].RoleName,
                ValidFrom: "",
                ValidTo: "",
                MaxHours: aRoles[0].MaxHours
            }]);
            MessageToast.show("Only the first role was retained for this Firefighter request.");
        } else if (sReqType === "F" && aRoles.length === 1) {
            this._oReviewModel?.setProperty("/roles", [{
                RoleName: aRoles[0].RoleName,
                ValidFrom: "",
                ValidTo: "",
                MaxHours: aRoles[0].MaxHours
            }]);
        }
        this.onUserInfoChange();
        this._validateRoleStep();
        this._invalidateSodResult();
    }

    public onLeaverReview(): void {
        this.onUserInfoChange();
        const sTargetUser = String(this._oReviewModel?.getProperty("/request/TargetUser") || "").trim();
        if (!sTargetUser) {
            return;
        }
        this._syncRequestFromForm();
        this._oReviewModel?.setProperty("/leaverStep", 2);
    }

    public onLeaverBackToUserInfo(): void {
        this._oReviewModel?.setProperty("/leaverStep", 1);
    }

    public onFirefighterChange(): void {
        this.onUserInfoChange();
    }

    public onAddRolePress(): void {
        const aRoles = this._getReviewRoles();
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType") || "J");
        if (sReqType === "F" && aRoles.length > 0) {
            MessageToast.show("A Firefighter request can contain exactly one emergency role.");
            return;
        }
        aRoles.push({ RoleName: "", ValidFrom: "", ValidTo: "" });
        this._oReviewModel?.setProperty("/roles", aRoles);
        this._validateRoleStep();
    }

    public onDeleteRole(oEvent: Event): void {
        const oContext = (oEvent.getSource() as any).getBindingContext("review");
        const iIndex = Number(oContext?.getPath?.().split("/").pop());
        if (!Number.isNaN(iIndex)) {
            const aRoles = this._getReviewRoles();
            aRoles.splice(iIndex, 1);
            this._oReviewModel?.setProperty("/roles", aRoles);
            this._validateRoleStep();
            this._invalidateSodResult();
        }
    }

    public onWizardCompleted(): void {
        return;
    }

    public async onReviewStepActivate(): Promise<void> {
        this._syncRequestFromForm();
        this._syncRolePreviewFromTable();
        this._invalidateSodResult();
    }

    public onRolePreviewChange(): void {
        this._syncRolePreviewFromTable();
        this._validateRoleStep();
        this._invalidateSodResult();
    }

    public async onCheckSod(): Promise<void> {
        await this._checkSod();
        const oSod = this._oReviewModel?.getProperty("/sod") as {
            checked?: boolean; conflicts?: SodConflict[]; message?: string;
        } | undefined;
        if (!oSod?.checked) {
            MessageBox.error(oSod?.message || "The SoD check could not be completed.", {
                title: "SoD Check Failed"
            });
            return;
        }

        const aConflicts = oSod.conflicts || [];
        if (aConflicts.length === 0) {
            MessageBox.success("No segregation-of-duties conflict was found for the selected role set.", {
                title: "SoD Check Result"
            });
            return;
        }

        this._showSodConflictDialog(aConflicts);
    }

    /** Shows conflicts as a scannable table instead of a long technical text block. */
    private _showSodConflictDialog(aConflicts: SodConflict[]): void {
        const mRiskLabel: Record<string, string> = {
            C: "Critical",
            H: "High",
            M: "Medium"
        };
        const mRiskState: Record<string, string> = {
            C: "Error",
            H: "Warning",
            M: "Information"
        };
        const aRows = aConflicts.map((oConflict) => ({
            ...oConflict,
            RiskText: mRiskLabel[oConflict.RiskLevel] || oConflict.RiskLevel || "Unknown",
            RiskState: mRiskState[oConflict.RiskLevel] || "None",
            RuleText: `${oConflict.RuleId} — ${oConflict.RuleName}`,
            RolesText: `${oConflict.Role1}  ↔  ${oConflict.Role2}`,
            ActionText: oConflict.SuggestedAction || "Review the conflict",
            ExemptionText: oConflict.IsExempt
                ? (oConflict.ExemptReason ? "Exempt: " + oConflict.ExemptReason : "Exempt")
                : "No active exemption",
            ExemptionState: oConflict.IsExempt ? "Success" : "None"
        }));
        const iCritical = aRows.filter((oRow) => oRow.RiskLevel === "C").length;
        const iHigh = aRows.filter((oRow) => oRow.RiskLevel === "H").length;
        const iMedium = aRows.filter((oRow) => oRow.RiskLevel === "M").length;
        const sSummary = [
            iCritical ? `${iCritical} Critical` : "",
            iHigh ? `${iHigh} High` : "",
            iMedium ? `${iMedium} Medium` : ""
        ].filter(Boolean).join(" · ");

        const oTable = new Table({
            growing: true,
            growingScrollToLoad: true,
            width: "100%",
            columns: [
                new Column({ header: new Text({ text: "Risk" }), width: "6rem" }),
                new Column({ header: new Text({ text: "Conflict rule" }), minScreenWidth: "Tablet", demandPopin: true }),
                new Column({ header: new Text({ text: "Conflicting roles" }), minScreenWidth: "Tablet", demandPopin: true }),
                new Column({ header: new Text({ text: "Suggested action" }), minScreenWidth: "Desktop", demandPopin: true }),
                new Column({ header: new Text({ text: "Exemption" }), minScreenWidth: "Desktop", demandPopin: true })
            ]
        });
        oTable.bindItems({
            path: "sodDialog>/rows",
            template: new ColumnListItem({
                cells: [
                    new ObjectStatus({ text: "{sodDialog>RiskText}", state: "{sodDialog>RiskState}" }),
                    new Text({ text: "{sodDialog>RuleText}", wrapping: true }),
                    new Text({ text: "{sodDialog>RolesText}", wrapping: true }),
                    new Text({ text: "{sodDialog>ActionText}", wrapping: true }),
                    new ObjectStatus({ text: "{sodDialog>ExemptionText}", state: "{sodDialog>ExemptionState}" })
                ]
            })
        });

        const oDialog = new Dialog({
            title: `SoD conflicts (${aRows.length})`,
            contentWidth: "72rem",
            contentHeight: "30rem",
            stretchOnPhone: true,
            content: [
                new VBox({
                    items: [
                        new Title({ text: "Review before submitting", level: "H5" }).addStyleClass("sapUiTinyMarginBottom"),
                        new MessageStrip({
                            text: `${aRows.length} conflict(s) found${sSummary ? `: ${sSummary}` : ""}. Critical conflicts require an approval rationale.`,
                            type: iCritical ? "Error" : "Warning",
                            showIcon: true,
                            showCloseButton: false
                        }).addStyleClass("sapUiTinyMarginBottom"),
                        oTable
                    ]
                }).addStyleClass("sapUiContentPadding")
            ],
            endButton: new Button({
                text: "Close",
                press: () => oDialog.close()
            }),
            afterClose: () => oDialog.destroy()
        });
        oDialog.setModel(new JSONModel({ rows: aRows }), "sodDialog");
        this.getView()?.addDependent(oDialog);
        oDialog.open();
    }

    private _syncRolePreviewFromTable(): void {
        const oTable = this.byId("roleTable") as Table;
        const bFirefighter = String(this._oReviewModel?.getProperty("/request/ReqType") || "J") === "F";
        const aPreviousRoles = this._getReviewRoles();
        const aRoles = oTable.getItems().map((oItem: any, iIndex: number) => {
            const aCells = oItem.getCells();
            return {
                RoleName: aCells[0]?.getValue?.() || "",
                ValidFrom: bFirefighter ? "" : this._formatReviewDate(this._getDatePickerValue(aCells[1])),
                ValidTo: bFirefighter ? "" : this._formatReviewDate(this._getDatePickerValue(aCells[2])),
                MaxHours: bFirefighter ? aPreviousRoles[iIndex]?.MaxHours : undefined
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
        return oDatePicker?.getDateValue?.() || oDatePicker?.getValue?.() || oDatePicker?.getDomRef?.("inner")?.value || "";
    }

    private _syncRequestFromForm(): void {
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType")
            || (this.byId("reqTypeSelect") as any)?.getSelectedKey?.() || "J");
        const sDurationHours = (this.byId("durationHoursInput") as Input)?.getValue?.().trim() || "";
        const iDurationHours = Number(sDurationHours);
        this._oReviewModel?.setProperty("/request", {
            ReqType: sReqType,
            TargetUser: (sReqType === "L"
                ? ((this.byId("leaverTargetUserInput") as Input)?.getValue?.()
                    || this._oReviewModel?.getProperty("/request/TargetUser") || "")
                : ((this.byId("targetUserInput") as Input)?.getValue?.() || "")).trim().toUpperCase(),
            Email: sReqType === "J" ? ((this.byId("emailInput") as Input)?.getValue?.() || "") : "",
            FirstName: sReqType === "J" ? ((this.byId("firstNameInput") as Input)?.getValue?.() || "") : "",
            LastName: sReqType === "J" ? ((this.byId("lastNameInput") as Input)?.getValue?.() || "") : "",
            Department: sReqType === "J" || sReqType === "M" ? ((this.byId("departmentInput") as Input)?.getValue?.() || "") : "",
            TicketId: sReqType === "F" ? ((this.byId("ticketIdInput") as Input)?.getValue?.() || "") : "",
            Reason: sReqType === "F" ? ((this.byId("reasonInput") as any)?.getValue?.() || "") : "",
            // OData exposes DurationHours as Edm.Byte; sending a string (for example "2") is rejected by Gateway.
            DurationHours: sReqType === "F" && Number.isInteger(iDurationHours) ? iDurationHours : ""
        });
    }

    public async onSaveDraft(): Promise<void> {
        BusyIndicator.show(0);
        try {
            const oModel = this.getView()?.getModel() as ODataModel;
            const oDraftContext = await this._ensureDraftContext(oModel);
            await this._persistRoles(oModel, oDraftContext);
            await this._executeDraftAction(oModel, oDraftContext, "Prepare");
            await this._executeDraftAction(oModel, oDraftContext, "Activate");
            BusyIndicator.hide();
            MessageToast.show("Request saved successfully.");
            this._oDraftContext = null;
            this.onNavBack();
        } catch (oError: any) {
            BusyIndicator.hide();
            MessageBox.error("Save failed: " + (oError.message || "Unknown error"));
        }
    }

    public async onSubmitApproval(): Promise<void> {
        this._setSubmitState(true, "Creating request draft...", false);
        try {
            const oModel = this.getView()?.getModel() as ODataModel;
            const oDraftContext = await this._runSubmitStage(
                "Creating request draft...",
                () => this._ensureDraftContext(oModel)
            );
            await this._runSubmitStage(
                "Saving requested role...",
                () => this._persistRoles(oModel, oDraftContext)
            );
            const oSodResult = await this._runSubmitStage(
                "Checking segregation-of-duties rules...",
                () => this._checkSod(oDraftContext)
            );
            if (oSodResult.hasCritical) {
                MessageToast.show("Critical SoD conflict detected. Submission is allowed; approval will require a rationale.");
            }
            await this._runSubmitStage(
                "Validating request data...",
                () => this._executeDraftAction(oModel, oDraftContext, "Prepare")
            );
            await this._runSubmitStage(
                "Activating request...",
                () => this._executeDraftAction(oModel, oDraftContext, "Activate")
            );
            const sReqUuid = String((oDraftContext as any).getProperty("ReqUuid"));
            const sActivePath = `/Request(ReqUuid=${sReqUuid},IsActiveEntity=true)`;
            const oActiveBinding = oModel.bindContext(sActivePath);
            const oActiveContext = oActiveBinding.getBoundContext() as Context;
            if (!oActiveContext) {
                throw new Error("The activated request could not be loaded for submission.");
            }
            const oSubmitAction = oModel.bindContext(
                `${this.SERVICE_NAMESPACE}.submitForApproval(...)`,
                oActiveContext
            ) as any;
            await this._runSubmitStage("Submitting for approval...", async () => {
                const oSubmitPromise = oSubmitAction.execute(this.CHANGE_GROUP_ID);
                await this._submitChanges(oModel);
                await oSubmitPromise;
            });
            this._setSubmitState(false, "", false);
            MessageToast.show("Request submitted for approval successfully!");
            this._oDraftContext = null;
            this.onNavBack();
        } catch (oError: any) {
            const sError = String(oError?.message || "Unknown error");
            const bTimedOut = sError.includes("did not respond within");
            this._setSubmitState(false, "", bTimedOut);
            MessageBox.error(
                bTimedOut
                    ? `${sError}\n\nThe request status is unknown. Do not submit again; check the Dashboard or SAP Gateway log first.`
                    : "Submit failed: " + sError
            );
        }
    }

    private async _runSubmitStage<T>(sStage: string, fnOperation: () => Promise<T>): Promise<T> {
        this._setSubmitState(true, sStage, false);
        let iTimeout: ReturnType<typeof setTimeout> | undefined;
        const oTimeout = new Promise<never>((_, reject) => {
            iTimeout = setTimeout(() => {
                reject(new Error(`${sStage} did not respond within ${this.SUBMIT_TIMEOUT_MS / 1000} seconds.`));
            }, this.SUBMIT_TIMEOUT_MS);
        });
        try {
            return await Promise.race([fnOperation(), oTimeout]);
        } finally {
            if (iTimeout !== undefined) {
                clearTimeout(iTimeout);
            }
        }
    }

    private _setSubmitState(bBusy: boolean, sStage: string, bTimedOut: boolean): void {
        if (bBusy) {
            if (!this._oSubmitBusyDialog) {
                this._oSubmitBusyDialog = new BusyDialog({
                    title: "Submitting request",
                    text: sStage
                });
            } else {
                this._oSubmitBusyDialog.setText(sStage);
            }
            this._oSubmitBusyDialog.open();
        } else {
            this._oSubmitBusyDialog?.close();
        }
        this._oReviewModel?.setProperty("/submission", {
            busy: bBusy,
            stage: sStage,
            timedOut: bTimedOut
        });
    }

    private async _persistRoles(oModel: ODataModel, oDraftContext: Context): Promise<void> {
        this._syncRolePreviewFromTable();
        const sDraftPath = oDraftContext.getPath();
        if (!sDraftPath || sDraftPath.includes("$uid")) {
            throw new Error("Draft request is not ready for role assignment.");
        }
        const aRoles = this._getReviewRoles().filter((oRole) => oRole.RoleName).map((oRole) => ({
            RoleName: oRole.RoleName,
            ValidFrom: oRole.ValidFrom || null,
            ValidTo: oRole.ValidTo || null
        }));
        const sRolePayload = JSON.stringify(aRoles);
        if (this._lastPersistedRolePayload === sRolePayload) {
            return;
        }
        const oRoleBinding = oModel.bindList(
            `${sDraftPath}/_Roles`, undefined, undefined, undefined,
            { $$updateGroupId: this.CHANGE_GROUP_ID }
        ) as ODataListBinding;
        // A new draft has no role items. Avoid a round trip just to read an empty association.
        const aExistingContexts = this._hasPersistedRoleItems
            ? await (oRoleBinding as any).requestContexts(0, 100)
            : [];
        const aDeletePromises = aExistingContexts.map((oContext: Context) => oContext.delete());
        const aCreatePromises = aRoles.map((oRole) => {
            const oRoleContext = oRoleBinding.create(oRole, true);
            return (oRoleContext as any).created?.() || Promise.resolve();
        });
        await this._submitChanges(oModel);
        await Promise.all([...aDeletePromises, ...aCreatePromises]);
        this._lastPersistedRolePayload = sRolePayload;
        this._hasPersistedRoleItems = aRoles.length > 0;
    }

    private async _ensureDraftContext(oModel: ODataModel): Promise<Context> {
        this._syncRequestFromForm();
        const oRequest = this._oReviewModel?.getProperty("/request") as RequestData;
        const sValidationError = this._validateRequest(oRequest, this._getReviewRoles());
        if (sValidationError) {
            throw new Error(sValidationError);
        }
        if (!this._oDraftContext) {
            await this._ensureNoDuplicateJoinerRequest(oModel, oRequest);
        }
        if (this._oDraftContext) {
            const sRequestPayload = JSON.stringify(oRequest);
            if (this._lastPersistedRequestPayload !== sRequestPayload) {
                Object.entries(oRequest).forEach(([sName, sValue]) => this._oDraftContext?.setProperty(sName, sValue));
                await this._submitChanges(oModel);
                this._lastPersistedRequestPayload = sRequestPayload;
            }
            return this._oDraftContext;
        }
        const oListBinding = oModel.bindList(
            "/Request", undefined, undefined, undefined,
            { $$updateGroupId: this.CHANGE_GROUP_ID }
        ) as ODataListBinding;
        this._oDraftContext = oListBinding.create({ ...oRequest }, true);
        await this._submitChanges(oModel);
        if (this._oDraftContext.getPath().includes("$uid")) {
            this._oDraftContext = null;
            throw new Error("Draft creation was rejected. Assign authorization object ZIAM_REQ with ACTVT 01 to the requester.");
        }
        this._lastPersistedRequestPayload = JSON.stringify(oRequest);
        return this._oDraftContext;
    }

    private async _executeDraftAction(oModel: ODataModel, oDraftContext: Context, sAction: "Prepare" | "Activate"): Promise<void> {
        const oAction = oModel.bindContext(`${this.SERVICE_NAMESPACE}.${sAction}(...)`, oDraftContext) as any;
        const oActionPromise = oAction.execute(this.CHANGE_GROUP_ID);
        await this._submitChanges(oModel);
        await oActionPromise;
    }

    private _submitChanges(oModel: ODataModel): Promise<void> {
        return oModel.submitBatch(this.CHANGE_GROUP_ID);
    }

    private _getReviewRoles(): RequestRole[] {
        return [...(this._oReviewModel?.getProperty("/roles") || [])] as RequestRole[];
    }

    private _setFieldValidity(oControl: any, bValid: boolean, sMessage: string): void {
        oControl?.setValueState?.(bValid ? "None" : "Error");
        oControl?.setValueStateText?.(bValid ? "" : sMessage);
    }

    private _validateRoleStep(): void {
        const oStep = this.byId("RoleStep") as WizardStep;
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType") || "J");
        const iRoleCount = this._getReviewRoles().filter((oRole) => Boolean(oRole.RoleName?.trim())).length;
        oStep.setValidated(sReqType === "L" || (sReqType === "F" ? iRoleCount === 1 : iRoleCount >= 1));
    }

    private _getEmptyRequest(): RequestData {
        return {
            TargetUser: "", Email: "", FirstName: "", LastName: "", Department: "", ReqType: "J",
            TicketId: "", Reason: "", DurationHours: ""
        };
    }

    private _getReviewData(): object {
        return {
            request: this._getEmptyRequest(),
            roles: [],
            sod: { checking: false, checked: false, hasCritical: false, conflicts: [], message: "" },
            leaverStep: 1,
            submission: { busy: false, stage: "", timedOut: false }
        };
    }

    private _validateRequest(oRequest: RequestData, aRoles: RequestRole[]): string | undefined {
        if (!String(oRequest?.TargetUser || "").trim()) {
            return "SAP user is required.";
        }
        if (oRequest.ReqType === "J" && !this._isEmailValid(String(oRequest.Email || ""))) {
            return "Enter a valid email address for a Joiner request.";
        }
        if (oRequest.ReqType === "M" && !oRequest.Department) {
            return "New department is required for a Mover request.";
        }
        if (oRequest.ReqType !== "L" && !aRoles.some((oRole) => oRole.RoleName)) {
            return "At least one requested role is required.";
        }
        if (oRequest.ReqType !== "F") {
            return undefined;
        }
        if (aRoles.filter((oRole) => oRole.RoleName).length !== 1) {
            return "A Firefighter request must contain exactly one emergency role.";
        }
        if (!oRequest.TicketId || !oRequest.Reason) {
            return "Ticket ID and emergency reason are required for Firefighter access.";
        }
        const iDuration = Number(oRequest.DurationHours);
        return Number.isInteger(iDuration) && iDuration >= 1 && iDuration <= 24
            ? undefined
            : "Duration must be an integer from 1 to 24 hours.";
    }

    private _isEmailValid(sEmail: string): boolean {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(sEmail.trim());
    }

    private async _ensureNoDuplicateJoinerRequest(oModel: ODataModel, oRequest: RequestData): Promise<void> {
        if (oRequest.ReqType !== "J") {
            return;
        }

        const sTargetUser = String(oRequest.TargetUser || "").trim().toUpperCase();
        if (!sTargetUser) {
            return;
        }

        const oDuplicateBinding = oModel.bindList(
            "/Request",
            undefined,
            undefined,
            [
                new Filter("ReqType", FilterOperator.EQ, "J"),
                new Filter("TargetUser", FilterOperator.EQ, sTargetUser),
                new Filter("IsActiveEntity", FilterOperator.EQ, true)
            ],
            {
                $$groupId: "$direct",
                $select: "ReqUuid,ReqId,Status"
            }
        ) as ODataListBinding;
        const aExistingRequests = await (oDuplicateBinding as any).requestContexts(0, 20) as Context[];
        const oDuplicate = aExistingRequests.find((oContext) => String(oContext.getProperty("Status") || "") !== "04");

        if (oDuplicate) {
            const sReqId = String(oDuplicate.getProperty("ReqId") || "existing request");
            throw new Error(`A Joiner request (${sReqId}) already exists for SAP user ${sTargetUser}.`);
        }
    }

    private _invalidateSodResult(): void {
        this._oReviewModel?.setProperty("/sod", {
            checking: false,
            checked: false,
            hasCritical: false,
            conflicts: [],
            message: ""
        });
    }

    private async _checkSod(oExistingDraftContext?: Context): Promise<{ hasCritical: boolean }> {
        if (this._sodCheckInFlight) {
            return this._sodCheckInFlight;
        }
        const oCheckPromise = this._runSodCheck(oExistingDraftContext);
        this._sodCheckInFlight = oCheckPromise;
        try {
            return await oCheckPromise;
        } finally {
            if (this._sodCheckInFlight === oCheckPromise) {
                this._sodCheckInFlight = null;
            }
        }
    }

    private async _runSodCheck(oExistingDraftContext?: Context): Promise<{ hasCritical: boolean }> {
        this._syncRequestFromForm();
        this._syncRolePreviewFromTable();
        const oRequest = this._oReviewModel?.getProperty("/request") as RequestData;
        if (!oRequest?.TargetUser || !this._getReviewRoles().some((oRole) => oRole.RoleName)) {
            this._oReviewModel?.setProperty("/sod", { checking: false, checked: false, hasCritical: false, conflicts: [], message: "" });
            return { hasCritical: false };
        }
        const bTemporaryDraft = !oExistingDraftContext;
        let oDraftContext: Context | undefined;
        let oModel: ODataModel | undefined;
        try {
            this._oReviewModel?.setProperty("/sod/checking", true);
            oModel = this.getView()?.getModel() as ODataModel;
            oDraftContext = oExistingDraftContext || await this._ensureDraftContext(oModel);
            if (!oExistingDraftContext) {
                await this._persistRoles(oModel, oDraftContext);
            }
            const oAction = oModel.bindContext(`${this.SERVICE_NAMESPACE}.checkSod(...)`, oDraftContext) as any;
            const oActionPromise = oAction.execute(this.CHANGE_GROUP_ID);
            await this._submitChanges(oModel);
            await oActionPromise;
            const oResult = await oAction.getBoundContext?.()?.requestObject?.();
            const aConflicts = (oResult?.value || oResult?.Conflicts || []).map((oConflict: any) => this._normalizeSodConflict(oConflict));
            const hasCritical = aConflicts.some((oConflict: SodConflict) => oConflict.RiskLevel === "C");
            this._oReviewModel?.setProperty("/sod", {
                checking: false, checked: true, hasCritical, conflicts: aConflicts,
                message: aConflicts.length ? `${aConflicts.length} SoD conflict(s) found.` : "No SoD conflicts found."
            });
            return { hasCritical };
        } catch (oError) {
            const sErrorText = this._getODataErrorMessage(oError);
            // Keep the technical payload in the browser console for Basis/development diagnosis.
            // The page displays the server message as well, so a failed pre-check is not mistaken for "no conflict".
            console.error("SoD check failed", oError);
            this._oReviewModel?.setProperty("/sod", {
                checking: false, checked: false, hasCritical: false, conflicts: [],
                message: `SoD check failed: ${sErrorText}`
            });
            return { hasCritical: false };
        } finally {
            // A manual pre-check needs a draft only because checkSod is a
            // bound RAP action. It is not a business request yet. Discard it
            // after the result is read, including error paths. Submit passes
            // its own draft context and keeps it until Activate/submit ends.
            if (bTemporaryDraft && oDraftContext && oModel) {
                await this._discardDraft(oModel, oDraftContext);
            }
        }
    }

    private _getODataErrorMessage(oError: any): string {
        const sResponseText = oError?.cause?.responseText || oError?.responseText;
        if (typeof sResponseText === "string" && sResponseText) {
            try {
                const oPayload = JSON.parse(sResponseText);
                const vServerMessage = oPayload?.error?.message?.value || oPayload?.error?.message;
                if (typeof vServerMessage === "string" && vServerMessage) {
                    return vServerMessage;
                }
            } catch (_parseError) {
                // Fall through to the regular UI5 error properties.
            }
        }
        const vMessage = oError?.error?.message || oError?.message;
        return typeof vMessage === "string" && vMessage
            ? vMessage
            : "No technical message was returned by the service.";
    }

    private _normalizeSodConflict(oConflict: any): SodConflict {
        return {
            RuleId: oConflict.RuleId || oConflict.rule_id || "",
            RuleName: oConflict.RuleName || oConflict.rule_name || "",
            Role1: oConflict.Role1 || oConflict.AgrName1 || oConflict.agr_name_1 || "",
            Role2: oConflict.Role2 || oConflict.AgrName2 || oConflict.agr_name_2 || "",
            RiskLevel: oConflict.RiskLevel || oConflict.risk_level || "",
            IsExempt: Boolean(oConflict.IsExempt || oConflict.is_exempt),
            ExemptReason: oConflict.ExemptReason || oConflict.exempt_reason || "",
            SuggestedAction: oConflict.SuggestedAction || oConflict.suggested_action || "",
            IsLocked: Boolean(oConflict.IsLocked || oConflict.is_locked),
            LastLogin: oConflict.LastLogin || oConflict.last_login || ""
        };
    }

    public onDepartmentVHRequest(): void {
        if (!this._oDeptDialog) {
            this._oDeptDialog = new SelectDialog({
                title: "Select Department", noDataText: "No departments found",
                items: { path: "deptVH>/items", template: new StandardListItem({ title: "{deptVH>DepartmentID}", description: "{deptVH>DepartmentName}" }) },
                search: (oEvent: Event) => { this._onDeptDialogSearch(oEvent); },
                confirm: (oEvent: Event) => { this._onDeptDialogConfirm(oEvent); }
            });
            this.getView()?.addDependent(this._oDeptDialog);
            this._oDeptDialog.setModel(this._oDeptModel as JSONModel, "deptVH");
        }
        this._loadDeptData();
        this._oDeptDialog.open("");
    }

    private _loadDeptData(sFilter?: string): void {
        let sUrl = this.DEPT_VH_URL + "?$top=200&$format=json";
        if (sFilter) {
            sUrl += "&$filter=contains(DepartmentName,'" + encodeURIComponent(sFilter) + "') or contains(DepartmentID,'" + encodeURIComponent(sFilter) + "')";
        }
        fetch(sUrl, { credentials: "include", headers: { Accept: "application/json" } })
            .then((response) => response.json())
            .then((data: any) => this._oDeptModel?.setProperty("/items", data.value || []))
            .catch(() => MessageToast.show("Failed to load departments."));
    }

    private _onDeptDialogSearch(oEvent: Event): void {
        this._loadDeptData(oEvent.getParameter("value") as string);
    }

    private _onDeptDialogConfirm(oEvent: Event): void {
        const oSelectedItem = oEvent.getParameter("selectedItem") as any;
        if (oSelectedItem) {
            const sDeptId = oSelectedItem.getBindingContext("deptVH").getProperty("DepartmentID");
            (this.byId("departmentInput") as Input).setValue(sDeptId);
            this._oReviewModel?.setProperty("/request/Department", sDeptId);
            this.onUserInfoChange();
        }
    }

    public onRoleVHRequest(oEvent: Event): void {
        this._oRoleSourceInput = oEvent.getSource() as Input;
        if (!this._oRoleDialog) {
            this._oRoleDialog = new SelectDialog({
                title: "Select Role", noDataText: "No roles found",
                items: { path: "roleVH>/items", template: new StandardListItem({ title: "{roleVH>RoleName}", description: "{roleVH>Description}" }) },
                search: (oEvt: Event) => { this._onRoleDialogSearch(oEvt); },
                confirm: (oEvt: Event) => { this._onRoleDialogConfirm(oEvt); }
            });
            this.getView()?.addDependent(this._oRoleDialog);
            this._oRoleDialog.setModel(this._oRoleModel as JSONModel, "roleVH");
        }
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType") || "J");
        this._loadRoleData(undefined, sReqType === "F");
        this._oRoleDialog.open("");
    }

    private _loadRoleData(sSearch?: string, bFirefighter = false): void {
        let sUrl = (bFirefighter ? this.FIREFIGHTER_ROLE_VH_URL : this.ROLE_VH_URL) + "?$top=200&$format=json";
        if (sSearch) {
            sUrl += bFirefighter
                ? "&$filter=contains(RoleName,'" + encodeURIComponent(sSearch) + "')"
                : "&$search=" + encodeURIComponent(sSearch);
        }
        fetch(sUrl, { credentials: "include", headers: { Accept: "application/json" } })
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                return response.json();
            })
            .then((data: any) => {
                const aItems = data.value || [];
                this._oRoleModel?.setProperty("/items", aItems);
                if (bFirefighter && !aItems.length) {
                    MessageToast.show("No active Firefighter role is configured. Maintain ZIAM_FF_ROLE first.");
                }
            })
            .catch(() => MessageToast.show("Failed to load roles."));
    }

    private _onRoleDialogSearch(oEvent: Event): void {
        const sReqType = String(this._oReviewModel?.getProperty("/request/ReqType") || "J");
        this._loadRoleData(oEvent.getParameter("value") as string, sReqType === "F");
    }

    private _onRoleDialogConfirm(oEvent: Event): void {
        const oSelectedItem = oEvent.getParameter("selectedItem") as any;
        if (oSelectedItem && this._oRoleSourceInput) {
            const sRoleName = oSelectedItem.getBindingContext("roleVH").getProperty("RoleName");
            const iMaxHours = Number(oSelectedItem.getBindingContext("roleVH").getProperty("MaxHours") || 0);
            this._oRoleSourceInput.setValue(sRoleName);
            const oReviewContext = this._oRoleSourceInput.getBindingContext("review");
            const sRolePath = oReviewContext?.getPath();
            if (sRolePath) {
                this._oReviewModel?.setProperty(`${sRolePath}/RoleName`, sRoleName);
                this._oReviewModel?.setProperty(`${sRolePath}/MaxHours`, iMaxHours);
            }
            this._syncRolePreviewFromTable();
            this._validateRoleStep();
            this._invalidateSodResult();
        }
    }

    public async onNavBack(): Promise<void> {
        await this._discardOpenDraft();
        this._resetDraftTracking();
        ((this.getOwnerComponent() as UIComponent).getRouter() as Router).navTo("RouteDashboard");
    }

    public onExit(): void {
        // Best effort only. A browser refresh cannot wait for an OData round
        // trip, so scheduled backend draft housekeeping remains advisable.
        void this._discardOpenDraft();
    }

    private async _discardOpenDraft(): Promise<void> {
        const oDraftContext = this._oDraftContext;
        if (!oDraftContext) {
            return;
        }
        const oModel = this.getView()?.getModel() as ODataModel;
        await this._discardDraft(oModel, oDraftContext);
    }

    private async _discardDraft(oModel: ODataModel, oDraftContext: Context): Promise<void> {
        if (this._oDraftContext === oDraftContext) {
            this._oDraftContext = null;
        }
        try {
            const oDiscardAction = oModel.bindContext(
                `${this.SERVICE_NAMESPACE}.Discard(...)`,
                oDraftContext
            ) as any;
            const oDiscardPromise = oDiscardAction.execute(this.CHANGE_GROUP_ID);
            await this._submitChanges(oModel);
            await oDiscardPromise;
        } catch {
            // If the draft has already disappeared, deleting the local draft
            // context is sufficient. Do not surface cleanup failures to the
            // requester after a successful check or navigation.
            try {
                await oDraftContext.delete(this.CHANGE_GROUP_ID);
                await this._submitChanges(oModel);
            } catch {
                // Best effort; the backend housekeeping job handles orphaned
                // drafts caused by browser termination or network loss.
            }
        } finally {
            this._resetDraftTracking();
        }
    }

    private _resetDraftTracking(): void {
        this._lastPersistedRequestPayload = "";
        this._lastPersistedRolePayload = "";
        this._hasPersistedRoleItems = false;
    }
}
