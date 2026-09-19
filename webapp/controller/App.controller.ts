import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import FlexibleColumnLayout from "sap/f/FlexibleColumnLayout";
import ToolPage from "sap/tnt/ToolPage";
import Button from "sap/m/Button";

/**
 * @namespace ziam.dashboard.controller
 */
export default class App extends Controller {

    public onInit(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.attachRouteMatched(this.onRouteMatched, this);
    }

    public onRouteMatched(oEvent: Event): void {
        const sRouteName = oEvent.getParameter("name");
        const oFCL = this.byId("flexibleColumnLayout") as FlexibleColumnLayout;

        if (oFCL) {
            if (sRouteName === "RouteDetail") {
                (oFCL as any).setLayout("TwoColumnsMidExpanded");
            } else if (sRouteName === "RouteDashboard" || sRouteName === "RouteWizard") {
                (oFCL as any).setLayout("OneColumn");
            }
        }
    }

    public onNavToDashboard(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }

    public onToggleSideNavigation(): void {
        const toolPage = this.byId("toolPage") as ToolPage;
        toolPage.toggleSideContentMode();
        const toggleButton = this.byId("toggleSideNavigationButton") as Button;
        toggleButton.setTooltip(toolPage.getSideExpanded() ? "Collapse navigation" : "Expand navigation");
    }
}
