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

/**
 * @namespace hrrequest.hrm.controller
 */
export default class Dashboard extends Controller {

    public onInit(): void {

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

        const oTable = this.byId("requestTable") as Table;
        const oBinding = oTable.getBinding("items") as ListBinding;
        oBinding.filter(aFilters, "Application");
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
