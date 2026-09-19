import TableDelegate from "sap/ui/mdc/odata/v4/TableDelegate";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";

type PropertyInfo = {
    name: string;
    path: string;
    label: string;
    sortable: boolean;
    filterable: boolean;
};

type BindingInfo = {
    path?: string;
    parameters?: Record<string, unknown>;
    filters?: Filter[];
};

type MdcTable = {
    data: (sKey: string) => unknown;
};

// eslint-disable-next-line @sap-ux/fiori-tools/sap-no-global-variable
const PROPERTY_INFO: PropertyInfo[] = [
    { name: "TargetUser", path: "TargetUser", label: "Employee", sortable: true, filterable: true },
    { name: "ReqId", path: "ReqId", label: "Request", sortable: true, filterable: true },
    { name: "ReqTypeText", path: "ReqTypeText", label: "Request Type", sortable: true, filterable: true },
    { name: "Department", path: "Department", label: "Department", sortable: true, filterable: true },
    { name: "Email", path: "Email", label: "Email", sortable: true, filterable: true },
    { name: "CreatedAt", path: "CreatedAt", label: "Created At", sortable: true, filterable: true },
    { name: "CreatedBy", path: "CreatedBy", label: "Request Creator", sortable: true, filterable: true },
    { name: "LastChangedAt", path: "LastChangedAt", label: "Last Changed At", sortable: true, filterable: true },
    { name: "LastChangedBy", path: "LastChangedBy", label: "Changed By", sortable: true, filterable: true },
    { name: "ApprovedBy", path: "ApprovedBy", label: "Approved By", sortable: true, filterable: true },
    { name: "Status", path: "Status", label: "Status", sortable: true, filterable: true }
];

/**
 * OData V4 delegate for the request list.
 *
 * The standard delegate supplies MDC sort/filter handling. This small
 * application-specific extension supplies the entity-set path and keeps the
 * active-request filter when MDC rebinds the table after personalization.
 */
// eslint-disable-next-line @sap-ux/fiori-tools/sap-no-global-variable
const RequestTableDelegate = Object.assign({}, TableDelegate, {
    fetchProperties(): Promise<PropertyInfo[]> {
        return Promise.resolve(PROPERTY_INFO);
    },

    updateBindingInfo(oTable: MdcTable, oBindingInfo: BindingInfo): void {
        TableDelegate.updateBindingInfo(oTable, oBindingInfo);
        oBindingInfo.path = "/Request";
        oBindingInfo.parameters = {
            ...(oBindingInfo.parameters || {}),
            $count: true
        };

        const aApplicationFilters = oTable.data("applicationFilters") as Filter[] | undefined;
        const aMdcFilters = oBindingInfo.filters || [];
        oBindingInfo.filters = aApplicationFilters?.length
            ? aApplicationFilters.concat(aMdcFilters)
            : [new Filter("IsActiveEntity", FilterOperator.EQ, true)].concat(aMdcFilters);
    }
});

export default RequestTableDelegate;
