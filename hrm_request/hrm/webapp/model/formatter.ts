import DateFormat from "sap/ui/core/format/DateFormat";

function toDate(vValue: unknown): Date | null {
    if (vValue instanceof Date) {
        return Number.isNaN(vValue.getTime()) ? null : vValue;
    }

    if (typeof vValue === "number") {
        const oDate = new Date(vValue);
        return Number.isNaN(oDate.getTime()) ? null : oDate;
    }

    if (typeof vValue === "string" && vValue.trim().length > 0) {
        const oDate = new Date(vValue);
        return Number.isNaN(oDate.getTime()) ? null : oDate;
    }

    return null;
}

export function formatDateTime(vValue: unknown): string {
    const oDate = toDate(vValue);
    return oDate
        ? DateFormat.getDateTimeInstance({ pattern: "dd.MM.yyyy HH:mm:ss" }).format(oDate, false)
        : "";
}

/**
 * RequestedBy is the business actor, while CreatedBy is the technical
 * fallback for older records where RequestedBy was not persisted.
 */
export function formatRequestCreator(vRequestedBy: unknown, vCreatedBy: unknown): string {
    const sRequestedBy = typeof vRequestedBy === "string" ? vRequestedBy.trim() : "";
    const sCreatedBy = typeof vCreatedBy === "string" ? vCreatedBy.trim() : "";
    return sRequestedBy || sCreatedBy;
}

export default {
    formatDateTime,
    formatRequestCreator
};
