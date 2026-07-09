import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import Event from "sap/ui/base/Event";
import Context from "sap/ui/model/odata/v4/Context";
import MessageToast from "sap/m/MessageToast";
import Button from "sap/m/Button";
import ObjectStatus from "sap/m/ObjectStatus";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class RequestDetail extends Controller {

    public onInit(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteDetail")?.attachPatternMatched(this._onRouteMatched, this);
    }

    private _onRouteMatched(oEvent: Event): void {
        const oArgs = oEvent.getParameter("arguments") as any;
        const sReqUuid = oArgs.ReqUuid;

        const oView = this.getView();
        if (oView) {
            const oBinding = oView.bindElement({
                path: `/Request(ReqUuid=${sReqUuid},IsActiveEntity=true)`,
                events: {
                    dataReceived: () => {
                        // Use setTimeout to ensure context data is available
                        setTimeout(() => this._updateButtonVisibility(), 100);
                    }
                }
            });
        }
    }

    private _updateButtonVisibility(): void {
        const oContext = this.getView()?.getBindingContext();
        if (!oContext) return;

        // Request Status and StatusCriticality explicitly
        Promise.all([
            (oContext as any).requestProperty("Status"),
            (oContext as any).requestProperty("StatusCriticality")
        ]).then((aResults: any[]) => {
            const sStatus = aResults[0] as string;
            const iCriticality = aResults[1] as number;

            // Update button visibility based on status
            const btnEdit = this.byId("btnEdit") as Button;
            const btnDelete = this.byId("btnDelete") as Button;
            const btnSubmit = this.byId("btnSubmit") as Button;
            const btnApprove = this.byId("btnApprove") as Button;
            const btnReject = this.byId("btnReject") as Button;

            if (btnEdit) btnEdit.setVisible(sStatus === "01");
            if (btnDelete) btnDelete.setVisible(sStatus === "01");
            if (btnSubmit) btnSubmit.setVisible(sStatus === "01");
            if (btnApprove) btnApprove.setVisible(sStatus === "02");
            if (btnReject) btnReject.setVisible(sStatus === "02");

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

    public onEditPress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext("SAP__self.Edit(...)", oContext) as any;
        oAction.setParameter("PreserveChanges", true);
        oAction.execute().then(() => {
            MessageToast.show("Draft created. You can edit now.");
        }).catch((err: Error) => MessageToast.show("Edit Error: " + err.message));
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

        const oAction = oContext.getModel().bindContext("SAP__self.submitForApproval(...)", oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Submitted successfully!");
            oContext.refresh();
            setTimeout(() => this._updateButtonVisibility(), 500);
        }).catch((err: Error) => MessageToast.show("Submit Error: " + err.message));
    }

    public onApprovePress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext("SAP__self.approve(...)", oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Approved successfully!");
            oContext.refresh();
            setTimeout(() => this._updateButtonVisibility(), 500);
        }).catch((err: Error) => MessageToast.show("Approve Error: " + err.message));
    }

    public onRejectPress(): void {
        const oContext = this.getView()?.getBindingContext() as Context;
        if (!oContext) return;

        const oAction = oContext.getModel().bindContext("SAP__self.reject(...)", oContext) as any;
        oAction.execute().then(() => {
            MessageToast.show("Rejected successfully!");
            oContext.refresh();
            setTimeout(() => this._updateButtonVisibility(), 500);
        }).catch((err: Error) => MessageToast.show("Reject Error: " + err.message));
    }

    public onCloseDetail(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }
}
