import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";
import ListBinding from "sap/ui/model/ListBinding";
import SearchField from "sap/m/SearchField";
import ComboBox from "sap/m/ComboBox";
import Context from "sap/ui/model/Context";
import JSONModel from "sap/ui/model/json/JSONModel";
import MessageBox from "sap/m/MessageBox";
import MessageToast from "sap/m/MessageToast";
import EventBus from "sap/ui/core/EventBus";
import Spreadsheet from "sap/ui/export/Spreadsheet";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class Dashboard extends Controller {
    private readonly CREATE_BLOCKED_USER = "DEV-252";
    private readonly DEPT_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_dept_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_lreq_hdr.department'/ZI_IAM_DEPT_VH";
    private readonly ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_role_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_req_role.rolename'/ZI_IAM_ROLE_VH";
    private _refreshInFlight: Promise<void> | null = null;
    private _eventBus!: EventBus;
    private _requestListBinding?: ListBinding;
    private _countUpdateTimer = 0;

    public onInit(): void {
        this._eventBus = (this.getOwnerComponent() as UIComponent).getEventBus();
        this.getView()?.setModel(new JSONModel({ departments: [], roles: [] }), "filters");
        this.getView()?.setModel(new JSONModel({ count: 0, canCreate: false }), "listState");
        void this._loadFilterOptions();
        this._setCreateVisibilityByUser();
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        this._eventBus.subscribe("hrm", "requestChanged", this._onRequestChanged, this);
        oRouter.getRoute("RouteDashboard")?.attachPatternMatched(this._onDashboardRouteMatched, this);
    }

    public onExit(): void {
        this._eventBus.unsubscribe("hrm", "requestChanged", this._onRequestChanged, this);
        this._detachRequestListBinding();
        if (this._countUpdateTimer) {
            window.clearTimeout(this._countUpdateTimer);
            this._countUpdateTimer = 0;
        }
    }

    public onAfterRendering(): void {
        this._attachRequestListBinding();
    }

    private _onRequestChanged(): void {
        void this._refreshTable(false);
    }

    /** Re-read the active request list whenever a create/detail flow returns here. */
    private _onDashboardRouteMatched(): void {
        if (this.byId("requestTable")) {
            void this._refreshTable(false);
        }
    }

    public onCreateRequest(): void {
        const oListState = this.getView()?.getModel("listState") as JSONModel;
        if (!oListState?.getProperty("/canCreate")) {
            MessageToast.show("You are not authorized to create requests.");
            return;
        }
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteWizard");
    }

    /**
     * UI-only restriction requested by the business: DEV-252 must not see Create.
     * RAP create authorization remains the server-side security boundary.
     */
    private _setCreateVisibilityByUser(): void {
        const oListState = this.getView()?.getModel("listState") as JSONModel;
        const sUserId = (globalThis as any)?.sap?.ushell?.Container?.getUser?.()?.getId?.();
        const sNormalizedUserId = typeof sUserId === "string" ? sUserId.trim().toUpperCase() : "";
        const bCanCreate = sNormalizedUserId !== this.CREATE_BLOCKED_USER;
        oListState?.setProperty("/canCreate", bCanCreate);
    }

    public onSearch(oEvent: Event): void {
        this._applyFilters();
    }

    public onFilterChange(oEvent: Event): void {
        this._applyFilters();
    }

    /** Explicit refresh requested by the Go button. */
    public async onGo(): Promise<void> {
        this._applyFilters();
        await this._refreshTable(true);
    }

    public async onExportRequests(): Promise<void> {
        const oTable = this.byId("requestTable") as any;
        const oBinding = oTable?.getRowBinding?.() as (ListBinding & {
            requestContexts?: (iStart?: number, iLength?: number) => Promise<Context[]>;
            getCurrentContexts?: () => Context[];
        });
        if (!oBinding) {
            MessageBox.error("Request list is not ready for export.");
            return;
        }

        oTable.setBusy(true);
        let oSpreadsheet: Spreadsheet | null = null;
        try {
            const aContexts = await this._loadExportContexts(oBinding);
            const aRows = aContexts
                .map((oContext) => oContext.getObject() as Record<string, unknown>)
                .filter(Boolean)
                .map((oRequest) => this._mapRequestForExport(oRequest));

            if (!aRows.length) {
                MessageToast.show("No requests to export.");
                return;
            }

            oSpreadsheet = new Spreadsheet({
                workbook: {
                    columns: this._getExportColumns(),
                    context: {
                        application: "HR Request Manage",
                        title: "Requests",
                        sheetName: "Requests"
                    }
                },
                dataSource: aRows,
                fileName: `Requests_${this._getExportDateStamp()}.xlsx`,
                worker: false
            });
            await oSpreadsheet.build();
        } catch (oError: any) {
            MessageBox.error("Export failed: " + (oError?.message || "The request list could not be exported."));
        } finally {
            oSpreadsheet?.destroy();
            oTable.setBusy(false);
        }
    }

    private async _refreshTable(bShowMessage: boolean): Promise<void> {
        if (this._refreshInFlight) {
            return this._refreshInFlight;
        }
        const oTable = this.byId("requestTable") as any;
        const oBinding = oTable?.getRowBinding?.() as (ListBinding & {
            requestRefresh?: (sGroupId?: string) => Promise<void>;
        });
        if (!oBinding) {
            return;
        }

        this._refreshInFlight = (async () => {
            oTable.setBusy(true);
            try {
                if (typeof oBinding.requestRefresh === "function") {
                    await oBinding.requestRefresh("$direct");
                } else {
                    (oBinding as any).refresh("$direct");
                }
                await this._updateRequestCount(oBinding);
                if (bShowMessage) {
                    MessageToast.show("Request list refreshed.");
                }
            } catch (oError: any) {
                if (bShowMessage) {
                    MessageBox.error("Refresh failed: " + (oError?.message || "The request list could not be loaded."));
                }
            } finally {
                oTable.setBusy(false);
            }
        })();
        try {
            await this._refreshInFlight;
        } finally {
            this._refreshInFlight = null;
        }
    }

    private async _updateRequestCount(oBinding?: ListBinding): Promise<void> {
        const oTable = this.byId("requestTable") as any;
        const oListBinding = oBinding || oTable?.getRowBinding?.() as ListBinding;
        if (!oListBinding) return;

        const iContextCount = ((oListBinding as any).getCurrentContexts?.() as Context[] | undefined)?.length || 0;
        const oODataBinding = oListBinding as ListBinding & {
            getCount?: () => number | undefined;
            getLength?: () => number;
            getHeaderContext?: () => ({ requestProperty?: (sPath: string) => Promise<unknown> } | null);
            isLengthFinal?: () => boolean;
        };
        let iCount = oODataBinding.getCount?.();
        if (iCount === undefined) {
            const oHeaderContext = oODataBinding.getHeaderContext?.();
            if (oHeaderContext?.requestProperty) {
                try {
                    iCount = Number(await oHeaderContext.requestProperty("$count"));
                } catch {
                    return;
                }
            }
        }
        if (iCount === undefined) {
            const iLength = oODataBinding.getLength?.();
            if (
                typeof iLength === "number"
                && Number.isFinite(iLength)
                && iLength >= 0
                && oODataBinding.isLengthFinal?.() !== false
            ) {
                iCount = iLength;
            }
        }
        if ((iCount === undefined || iCount < iContextCount) && iContextCount > 0) {
            iCount = iContextCount;
        }
        if (typeof iCount === "number" && Number.isFinite(iCount)) {
            (this.getView()?.getModel("listState") as JSONModel)?.setProperty("/count", iCount);
        }
    }

    private async _loadExportContexts(oBinding: ListBinding & {
        requestContexts?: (iStart?: number, iLength?: number) => Promise<Context[]>;
        getCurrentContexts?: () => Context[];
        getLength?: () => number;
        isLengthFinal?: () => boolean;
    }): Promise<Context[]> {
        if (typeof oBinding.requestContexts !== "function") {
            return oBinding.getCurrentContexts?.() || [];
        }

        const aContexts: Context[] = [];
        const iPageSize = 200;
        const iMaxRows = 10000;

        for (let iStart = 0; iStart < iMaxRows; iStart += iPageSize) {
            const aPage = await oBinding.requestContexts(iStart, iPageSize);
            if (!aPage.length) {
                break;
            }
            aContexts.push(...aPage);

            const iLength = oBinding.getLength?.();
            if (
                aPage.length < iPageSize
                || (typeof iLength === "number" && oBinding.isLengthFinal?.() !== false && aContexts.length >= iLength)
            ) {
                break;
            }
        }

        return aContexts;
    }

    private _getExportColumns(): Array<Record<string, unknown>> {
        return [
            { label: "Employee", property: "Employee", width: 18 },
            { label: "Employee Name", property: "EmployeeName", width: 24 },
            { label: "Request", property: "Request", width: 14 },
            { label: "Request Type", property: "RequestType", width: 18 },
            { label: "Department", property: "Department", width: 14 },
            { label: "Email", property: "Email", width: 28 },
            { label: "Created At", property: "CreatedAt", width: 22 },
            { label: "Request Creator", property: "RequestCreator", width: 18 },
            { label: "Last Changed At", property: "LastChangedAt", width: 22 },
            { label: "Changed By", property: "ChangedBy", width: 18 },
            { label: "Approved By", property: "ApprovedBy", width: 18 },
            { label: "Status", property: "Status", width: 14 }
        ];
    }

    private _mapRequestForExport(oRequest: Record<string, unknown>): Record<string, string> {
        return {
            Employee: String(oRequest.TargetUser || ""),
            EmployeeName: [oRequest.FirstName, oRequest.LastName].filter(Boolean).join(" "),
            Request: String(oRequest.ReqId || ""),
            RequestType: String(oRequest.ReqTypeText || oRequest.ReqType || ""),
            Department: String(oRequest.Department || ""),
            Email: String(oRequest.Email || ""),
            CreatedAt: this._formatExportDateTime(oRequest.CreatedAt),
            RequestCreator: String(oRequest.RequestedBy || oRequest.CreatedBy || ""),
            LastChangedAt: this._formatExportDateTime(oRequest.LastChangedAt),
            ChangedBy: String(oRequest.LastChangedBy || ""),
            ApprovedBy: String(oRequest.ApprovedBy || ""),
            Status: String(oRequest.StatusText || oRequest.Status || "")
        };
    }

    private _formatExportDateTime(vValue: unknown): string {
        if (!vValue) {
            return "";
        }
        const oDate = vValue instanceof Date ? vValue : new Date(String(vValue));
        if (Number.isNaN(oDate.getTime())) {
            return String(vValue);
        }
        return oDate.toLocaleString();
    }

    private _getExportDateStamp(): string {
        return new Date().toISOString().slice(0, 10);
    }

    private _attachRequestListBinding(): void {
        const oTable = this.byId("requestTable") as any;
        const oBinding = oTable?.getRowBinding?.() as ListBinding;
        if (!oBinding || oBinding === this._requestListBinding) {
            return;
        }

        this._detachRequestListBinding();
        this._requestListBinding = oBinding;
        oBinding.attachChange(this._onRequestListBindingChanged, this);
        (oBinding as any).attachDataReceived?.(this._onRequestListBindingChanged, this);
        this._scheduleRequestCountUpdate();
    }

    private _detachRequestListBinding(): void {
        if (!this._requestListBinding) {
            return;
        }
        this._requestListBinding.detachChange(this._onRequestListBindingChanged, this);
        (this._requestListBinding as any).detachDataReceived?.(this._onRequestListBindingChanged, this);
        this._requestListBinding = undefined;
    }

    private _onRequestListBindingChanged(): void {
        this._scheduleRequestCountUpdate();
    }

    private _scheduleRequestCountUpdate(): void {
        if (this._countUpdateTimer) {
            window.clearTimeout(this._countUpdateTimer);
        }
        this._countUpdateTimer = window.setTimeout(() => {
            this._countUpdateTimer = 0;
            void this._updateRequestCount();
        }, 0);
    }

    private _applyFilters(): void {
        const aFilters: Filter[] = [
            new Filter("IsActiveEntity", FilterOperator.EQ, true)
        ];
        
        const oSearchField = this.byId("searchField") as SearchField;
        const sQuery = oSearchField.getValue();
        if (sQuery && sQuery.length > 0) {
            // Filter by TargetUser or LastName
            aFilters.push(new Filter({
                filters: [
                    new Filter("TargetUser", FilterOperator.Contains, sQuery),
                    new Filter("LastName", FilterOperator.Contains, sQuery)
                ],
                and: false
            }));
        }

        const oStatusFilter = this.byId("statusFilter") as ComboBox;
        const sStatus = oStatusFilter.getSelectedKey();
        if (sStatus) {
            aFilters.push(new Filter("Status", FilterOperator.EQ, sStatus));
        }

        const oDepartmentFilter = this.byId("departmentFilter") as ComboBox;
        const sDepartmentKey = oDepartmentFilter.getSelectedKey();
        const sDepartmentValue = sDepartmentKey || oDepartmentFilter.getValue().trim();
        if (sDepartmentValue) {
            aFilters.push(new Filter(
                "Department",
                sDepartmentKey ? FilterOperator.EQ : FilterOperator.Contains,
                sDepartmentValue
            ));
        }

        const oRoleFilter = this.byId("roleFilter") as ComboBox;
        const sRoleKey = oRoleFilter.getSelectedKey();
        const sRoleValue = sRoleKey || oRoleFilter.getValue().trim();
        if (sRoleValue) {
            aFilters.push(new Filter({
                path: "_Roles",
                operator: FilterOperator.Any,
                variable: "role",
                condition: new Filter(
                    "role/RoleName",
                    sRoleKey ? FilterOperator.EQ : FilterOperator.Contains,
                    sRoleValue
                )
            }));
        }

        const oTable = this.byId("requestTable") as any;
        oTable?.data("applicationFilters", aFilters);
        const oBinding = oTable?.getRowBinding?.() as ListBinding;
        if (!oBinding) {
            return;
        }
        oBinding.filter(aFilters, "Application");
        void this._updateRequestCount(oBinding);
    }

    private async _loadFilterOptions(): Promise<void> {
        try {
            const [oDepartmentResponse, oRoleResponse] = await Promise.all([
                fetch(`${this.DEPT_VH_URL}?$top=200&$format=json`, {
                    credentials: "include",
                    headers: { Accept: "application/json" }
                }),
                fetch(`${this.ROLE_VH_URL}?$top=200&$format=json`, {
                    credentials: "include",
                    headers: { Accept: "application/json" }
                })
            ]);

            const [oDepartmentData, oRoleData] = await Promise.all([
                oDepartmentResponse.json(),
                oRoleResponse.json()
            ]);
            const oFilterModel = this.getView()?.getModel("filters") as JSONModel;
            oFilterModel?.setProperty("/departments", oDepartmentData.value || []);
            oFilterModel?.setProperty("/roles", oRoleData.value || []);
        } catch {
            // The dashboard remains usable with free-text filters when value-help loading fails.
        }
    }

    public onItemSelect(oEvent: Event): void {
        const oContext = (
            oEvent.getParameter("bindingContext") ||
            (oEvent.getParameter("listItem") as any)?.getBindingContext?.() ||
            (oEvent.getSource() as any)?.getBindingContext?.()
        ) as Context;
        if (!oContext) {
            return;
        }
        const sReqUuid = oContext.getProperty("ReqUuid");

        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDetail", {
            ReqUuid: sReqUuid
        });
    }
}
