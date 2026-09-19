declare module "sap/ui/mdc/odata/v4/TableDelegate" {
    type TableDelegateFunction = (...args: any[]) => any;

    interface TableDelegateApi {
        [sMethod: string]: TableDelegateFunction | unknown;
        updateBindingInfo: TableDelegateFunction;
    }

    const TableDelegate: TableDelegateApi;
    export default TableDelegate;
}
