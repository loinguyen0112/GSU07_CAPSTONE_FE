import Controller from "sap/ui/core/mvc/Controller";
import UIComponent from "sap/ui/core/UIComponent";
import Router from "sap/m/routing/Router";
import JSONModel from "sap/ui/model/json/JSONModel";
import Event from "sap/ui/base/Event";
import MessageToast from "sap/m/MessageToast";

interface UserRecord { UserName?: string; FullName?: string; UserStatus?: string; }
interface RequestRecord { RequestUuid?: string; RequestId?: string; TargetUser?: string; FirstName?: string; LastName?: string; Status?: string; CreatedAt?: string; LastChangedAt?: string; }
interface AuditRecord { AuditId?: string; TargetUser?: string; ActionType?: string; PerformedBy?: string; ChangedAt?: string; }

/**
 * IAM monitoring dashboard. Operational actions remain in the existing ALV/request applications.
 * @namespace ziam.dashboard.controller
 */
export default class Dashboard extends Controller {
    private readonly BASE_URL = "/sap/opu/odata4/sap/zui_iam_dash_o4/srvd/sap/zsd_iam_dash/0001";
    private readonly CREATE_BLOCKED_USER = "DEV-252";
    private readonly actionLabels: Record<string, string> = {
        INA_CASE_CLOSE: "Inactivity case closed", INA_EXT_LOCK: "User locked by inactivity",
        INA_LOCK_BEGIN: "Inactivity case opened", INA_WARN_ERR: "Inactivity warning recorded",
        INA_LOCK_OK: "User lock completed", FF_REVOKE_OK: "Emergency access revoked",
        FF_GRANT_OK: "Emergency access granted", FF_GRANT_PENDING: "Emergency access pending",
        APPROVE_REQ: "Request approved", SOD_CRIT_APPR: "SoD exception approved"
    };

    public onInit(): void {
        this.getView()?.setModel(new JSONModel(this._emptyModel()), "dashboard");
        void this._loadDashboard();
    }
    public onRefresh(): void { void this._loadDashboard(true); }
    public onCreateRequest(): void {
        if (!this._canCreateRequest()) {
            MessageToast.show("You are not authorized to create requests.");
            return;
        }
        const router = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        router.navTo("RouteWizard");
    }
    public onRequestPress(oEvent: Event): void {
        const source = (oEvent.getParameter("listItem") as any) || oEvent.getSource();
        this._navigateToRequest(source?.getBindingContext("dashboard"));
    }

    /** Opens the same request-detail route when the request ID link is pressed. */
    public onRequestLinkPress(oEvent: Event): void {
        this._navigateToRequest((oEvent.getSource() as any)?.getBindingContext("dashboard"));
    }

    private _navigateToRequest(context: any): void {
        // The dashboard JSON model uses camelCase, but accept the original
        // OData names as well so navigation remains safe if the model is
        // rebound directly to the service in a future revision.
        const requestUuid = context?.getProperty("requestUuid")
            || context?.getProperty("RequestUuid")
            || context?.getProperty("ReqUuid");
        if (!requestUuid) {
            MessageToast.show("Request detail is unavailable for this row.");
            return;
        }

        const router = (this.getOwnerComponent() as UIComponent).getRouter() as Router;
        router.navTo("RouteDetail", { ReqUuid: String(requestUuid) });
    }

    private async _loadDashboard(showToast = false): Promise<void> {
        const model = this.getView()?.getModel("dashboard") as JSONModel;
        model?.setProperty("/busy", true); model?.setProperty("/error", "");
        try {
            const [users, requests, audits] = await Promise.all([
                this._read<UserRecord>("Users"), this._read<RequestRecord>("Requests"), this._read<AuditRecord>("AuditEvents")
            ]);
            model?.setData(this._buildModel(users, requests, audits));
            if (showToast) MessageToast.show("Dashboard refreshed");
        } catch {
            model?.setProperty("/error", "Dashboard data could not be loaded. Check the OData service and authorizations.");
            model?.setProperty("/lastRefresh", this._formatDateTime(new Date().toISOString()));
            if (showToast) MessageToast.show("Refresh failed");
        } finally { model?.setProperty("/busy", false); }
    }

    private async _read<T>(entity: string): Promise<T[]> {
        const response = await fetch(this.BASE_URL + "/" + entity + "?$top=5000&$format=json", {
            credentials: "include", headers: { Accept: "application/json" }
        });
        if (!response.ok) throw new Error(entity + ": HTTP " + response.status);
        const payload = await response.json() as { value?: T[] };
        return payload.value || [];
    }

    private _buildModel(users: UserRecord[], requests: RequestRecord[], audits: AuditRecord[]): any {
        const activeUsers = users.filter((item) => item.UserStatus === "Active").length;
        const definitions = [
            { key: "01", label: "Draft", state: "Information" }, { key: "02", label: "Submitted", state: "Warning" },
            { key: "03", label: "Approved", state: "Success" }, { key: "04", label: "Rejected", state: "Error" }
        ];
        const totalRequests = requests.length;
        const requestStatus = definitions.map((definition) => {
            const count = requests.filter((item) => item.Status === definition.key).length;
            const color = definition.key === "03" ? "Good" : definition.key === "04" ? "Error" : definition.key === "02" ? "Critical" : "Neutral";
            return { ...definition, color, count, percent: totalRequests ? Math.round(count / totalRequests * 100) : 0 };
        });
        const pendingRequests = requests.filter((item) => item.Status === "01" || item.Status === "02" || !item.Status).length;
        const recentAudits = [...audits].sort((left, right) => this._toMillis(right.ChangedAt) - this._toMillis(left.ChangedAt));
        const actionCounts = new Map<string, number>();
        recentAudits.forEach((item) => { const key = item.ActionType || "OTHER"; actionCounts.set(key, (actionCounts.get(key) || 0) + 1); });
        const topActions = [...actionCounts.entries()].sort((left, right) => right[1] - left[1]).slice(0, 5)
            .map(([key, count]) => ({ label: this.actionLabels[key] || key, count }));
        const trendCounts = new Map<string, number>();
        recentAudits.forEach((item) => {
            const day = (item.ChangedAt || "").slice(0, 10);
            if (day) trendCounts.set(day, (trendCounts.get(day) || 0) + 1);
        });
        const maxTrend = Math.max(...trendCounts.values(), 1);
        const auditTrend = [...trendCounts.entries()].sort((left, right) => left[0].localeCompare(right[0])).slice(-7)
            .map(([day, count]) => ({ day: day.slice(5), count, color: "Good", percent: Math.round(count / maxTrend * 100) }));
        const attentionRequests = requests.filter((item) => item.Status === "01" || item.Status === "02" || !item.Status)
            .sort((left, right) => this._toMillis(right.LastChangedAt || right.CreatedAt) - this._toMillis(left.LastChangedAt || left.CreatedAt))
            .slice(0, 10).map((item) => ({
                requestUuid: item.RequestUuid || "", requestId: item.RequestId || "(no ID)",
                targetUser: item.TargetUser || "–", fullName: [item.FirstName, item.LastName].filter(Boolean).join(" "),
                statusText: this._statusLabel(item.Status), state: item.Status === "02" ? "Warning" : "Information",
                changedAt: this._formatDateTime(item.LastChangedAt || item.CreatedAt)
            }));
        const recentActivity = recentAudits.slice(0, 10).map((item) => ({
            actionLabel: this.actionLabels[item.ActionType || ""] || item.ActionType || "Audit event",
            targetUser: item.TargetUser || "–", performedBy: item.PerformedBy || "–", changedAt: this._formatDateTime(item.ChangedAt)
        }));
        const today = new Date().toISOString().slice(0, 10);
        const auditToday = recentAudits.filter((item) => (item.ChangedAt || "").slice(0, 10) === today).length;
        return {
            busy: false, error: "", canCreate: this._canCreateRequest(),
            lastRefresh: this._formatDateTime(new Date().toISOString()), runBy: this._getCurrentUser(),
            kpi: { totalUsers: users.length, activeUsers, inactiveUsers: users.length - activeUsers, pendingRequests, auditToday },
            requestStatus, topActions, auditTrend, attentionRequests, recentActivity
        };
    }

    private _emptyModel(): any {
        return { busy: false, error: "", canCreate: this._canCreateRequest(), lastRefresh: "–", runBy: this._getCurrentUser(), kpi: {},
            requestStatus: [], topActions: [], auditTrend: [], attentionRequests: [], recentActivity: [] };
    }
    private _statusLabel(status?: string): string {
        return ({ "01": "Draft", "02": "Submitted", "03": "Approved", "04": "Rejected" } as Record<string, string>)[status || ""] || "Pending";
    }
    private _getCurrentUser(): string {
        try {
            const shell = (globalThis as any).sap?.ushell?.Container;
            return shell?.getUser?.().getId?.() || "Current SAP user";
        } catch { return "Current SAP user"; }
    }
    /**
     * UI-only restriction requested by the business: DEV-252 must not see Create.
     * Backend authorization remains the server-side security boundary.
     */
    private _canCreateRequest(): boolean {
        return this._getCurrentUser().trim().toUpperCase() !== this.CREATE_BLOCKED_USER;
    }
    private _toMillis(value?: string): number {
        const millis = value ? Date.parse(value) : 0;
        return Number.isNaN(millis) ? 0 : millis;
    }
    private _formatDateTime(value?: string): string {
        if (!value) return "–";
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return value;
        return new Intl.DateTimeFormat(undefined, { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).format(date);
    }
}
