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
import Table from "sap/m/Table";

/**
 * @namespace hrrequest.hrm.controller
 */
export default class RequestWizard extends Controller {

    private _oDraftContext: Context | null = null;

    public onInit(): void {
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.getRoute("RouteWizard")?.attachPatternMatched(this._onRouteMatched, this);
    }

    private _onRouteMatched(): void {
        const oModel = this.getView()?.getModel() as ODataModel;
        const oListBinding = oModel.bindList("/Request", undefined, undefined, undefined, { $$updateGroupId: "draftGroup" }) as ODataListBinding;

        this._oDraftContext = oListBinding.create({
            TargetUser: "",
            Email: "",
            FirstName: "",
            LastName: "",
            Department: ""
        }, true); // true for AtEnd
        
        this.getView()?.setBindingContext(this._oDraftContext);
    }

    public onUserInfoChange(oEvent: Event): void {
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
        const oTable = this.byId("roleTable") as Table;
        const oBinding = oTable.getBinding("items") as ODataListBinding;
        
        if (oBinding) {
            oBinding.create({
                RoleName: "",
                ValidFrom: new Date().toISOString().split("T")[0], // Today's date
                ValidTo: "9999-12-31" // Default end of time
            }, true);
        }
    }

    public onDeleteRole(oEvent: Event): void {
        const oButton = oEvent.getSource() as any;
        const oContext = oButton.getBindingContext() as Context;
        if (oContext) {
            oContext.delete().catch((err: any) => {
                MessageToast.show("Error deleting role: " + err.message);
            });
        }
    }

    public onWizardCompleted(): void {
        // Handle wizard completion if needed
    }

    public onSubmitApproval(): void {
        if (!this._oDraftContext) {
            return;
        }
        
        const oModel = this.getView()?.getModel() as ODataModel;
        
        // 1. Submit changes for the draft
        oModel.submitBatch("draftGroup").then(() => {
            // 2. Call Activate action
            const oActivateAction = oModel.bindContext("SAP__self.Activate(...)", this._oDraftContext as any);
            oActivateAction.execute().then(() => {
                const oActiveContext = oActivateAction.getBoundContext();
                // 3. Call submitForApproval action
                const oSubmitAction = oModel.bindContext("SAP__self.submitForApproval(...)", oActiveContext);
                oSubmitAction.execute().then(() => {
                    MessageToast.show("Submitted for approval successfully!");
                    this.onNavBack();
                }).catch((err) => {
                    MessageToast.show("Error submitting for approval: " + err.message);
                });
            }).catch((err) => {
                MessageToast.show("Error activating draft: " + err.message);
            });
        }).catch((err) => {
             MessageToast.show("Error saving draft: " + err.message);
        });
    }

    public onNavBack(): void {
        // if user navigates back, should probably discard draft if not submitted, but keep simple for now
        const oRouter = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        oRouter.navTo("RouteDashboard");
    }
}
