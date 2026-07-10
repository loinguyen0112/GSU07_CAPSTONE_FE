import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";
import ListBinding from "sap/ui/model/ListBinding";
import Table from "sap/m/Table";
import SearchField from "sap/m/SearchField";
import ComboBox from "sap/m/ComboBox";
import Context from "sap/ui/model/odata/v4/Context";
import JSONModel from "sap/ui/model/json/JSONModel";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class Dashboard extends Controller {
    private readonly DEPT_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_dept_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_lreq_hdr.department'/ZI_IAM_DEPT_VH";
    private readonly ROLE_VH_URL = "/sap/opu/odata4/sap/zui_iam_lifecycle_o4/srvd_f4/sap/zi_iam_role_vh/0001;ps='srvd-zsd_iam_lifecycle-0001';va='com.sap.gateway.srvd.zsd_iam_lifecycle.v0001.et-zc_iam_req_role.rolename'/ZI_IAM_ROLE_VH";

    public onInit(): void {
        this.getView()?.setModel(new JSONModel({ departments: [], roles: [] }), "filters");
        void this._loadFilterOptions();
    }

    public onCreateRequest(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteWizard");
    }

    public onSearch(oEvent: Event): void {
        this._applyFilters();
    }

    public onFilterChange(oEvent: Event): void {
        this._applyFilters();
    }

    private _applyFilters(): void {
        const aFilters: Filter[] = [];
        
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

        const oTable = this.byId("requestTable") as Table;
        const oBinding = oTable.getBinding("items") as ListBinding;
        oBinding.filter(aFilters, "Application");
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
        const oItem = oEvent.getParameter("listItem");
        const oContext = oItem.getBindingContext() as Context;
        const sReqUuid = oContext.getProperty("ReqUuid");

        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDetail", {
            ReqUuid: sReqUuid
        });
    }
}
