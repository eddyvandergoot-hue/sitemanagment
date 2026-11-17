# Generates the .xlsx files for SharePoint "New > List > From Excel" (roadmap 1, DESIGN_CUSTOMERS_SAFETY.md).
# One Excel table per workbook (the import reads the first table). Synthetic sample rows only, no real data.
# Output: artifacts/lists/Customers.xlsx and artifacts/lists/ProjectSafety.xlsx (gitignored, *.xlsx).
# Run: py -E -P artifacts/lists/make_list_templates.py
import datetime
import os

from openpyxl import Workbook
from openpyxl.worksheet.table import Table, TableStyleInfo

HERE = os.path.dirname(os.path.abspath(__file__))

LISTS = {
    "Customers": {
        # Header = internal column name (no spaces, so SharePoint keeps clean internal names). "Title" maps to the Title column.
        "columns": ["Title", "City", "Phone", "Active"],
        "rows": [
            ["TEST Customer", "Teststad", "+31 00 0000000", True],
            ["TEST Customer 2", "Testdorp", "+32 00 000000", False],
        ],
    },
    "ProjectSafety": {
        "columns": [
            "Title",               # ProjectKey = Text(Projects ID); unique (MS step)
            "PlanRelease",         # safety plan release / issue (text)
            "PlanStartDate",       # date
            "SupervisorPhone",     # phone of the GEA site supervisor (person = Projects.SiteManagers)
            "AssemblyPoint",       # multiple lines of text
            "FirstAidPhone",       # BHV + EHBO
            "EmergencyNumber",     # e.g. 112
            "FireNumber",
            "HospitalName",
            "HospitalAddress",
            "HospitalPostalCode",
            "HospitalCity",
            "HospitalPhone",
            "PoliceCity",
            "PolicePhone",
            "InspectionName",      # labour inspection (optional)
            "InspectionCity",
            "InspectionPhone",
        ],
        "rows": [
            ["TEST", "Rev. 1", datetime.date(2026, 11, 2), "+31 00 0000000", "TEST assembly point at the main gate",
             "+31 00 0000001", "112", "112", "TEST Hospital", "Teststraat 1", "0000 AA", "Teststad", "+31 00 0000002",
             "Teststad", "+31 00 0000003", "", "", ""],
        ],
    },
}


def build(name, spec):
    wb = Workbook()
    ws = wb.active
    ws.title = name
    ws.append(spec["columns"])
    for r in spec["rows"]:
        ws.append(r)
    for i, col in enumerate(spec["columns"], start=1):
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = max(14, len(col) + 4)
        if col.endswith("Date"):
            for row in range(2, 2 + len(spec["rows"])):
                ws.cell(row=row, column=i).number_format = "yyyy-mm-dd"
    ref = f"A1:{ws.cell(row=1 + len(spec['rows']), column=len(spec['columns'])).coordinate}"
    t = Table(displayName=f"tbl{name}", ref=ref)
    t.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws.add_table(t)
    out = os.path.join(HERE, f"{name}.xlsx")
    wb.save(out)
    return out, len(spec["columns"]), len(spec["rows"])


if __name__ == "__main__":
    for n, s in LISTS.items():
        path, ncol, nrow = build(n, s)
        print(f"{os.path.basename(path)}: {ncol} columns, {nrow} sample rows")
