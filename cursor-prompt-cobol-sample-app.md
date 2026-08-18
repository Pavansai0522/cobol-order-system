# Cursor Prompt — Generate Sample z/OS COBOL Application

Copy/paste the block below into Cursor's chat/composer.

---

I need you to generate a small, realistic z/OS mainframe application in COBOL, so I can use it as test input for a mainframe modernization assessment tool (AWS Transform). This needs to be a self-contained, moderately complex sample — not a "hello world" — so the assessment produces meaningful output (dependency mapping, business rule extraction, complexity scoring).

## Domain
Build a simple **Customer Order Management System** for a fictional retail company. This should mimic a realistic legacy batch-processing mainframe app.

## Requirements

Create the following file structure:

```
/cobol-order-system
  /src
    CUSTMAST.cbl     -- Customer master maintenance (add/update/inquire)
    ORDENTRY.cbl      -- Order entry program
    ORDPROC.cbl       -- Order processing / validation batch job
    INVUPDT.cbl       -- Inventory update program
    RPTGEN.cbl        -- End-of-day report generation
  /copybooks
    CUSTREC.cpy       -- Customer record layout
    ORDREC.cpy        -- Order record layout
    INVREC.cpy        -- Inventory record layout
  /jcl
    ORDDAILY.jcl      -- Daily batch job that runs ORDPROC -> INVUPDT -> RPTGEN in sequence
    CUSTMNT.jcl        -- Customer maintenance job
  /data
    sample-customers.txt   -- A few sample fixed-width customer records
    sample-orders.txt      -- A few sample fixed-width order records
  README.md
```

## Functional requirements (embed real business logic, not stubs)

1. **CUSTMAST.cbl** — VSAM-style customer master file maintenance. Include validation logic (customer ID format check, credit limit check), and at least 2-3 realistic business rules (e.g., "credit limit cannot be exceeded," "inactive customers cannot place new orders").
2. **ORDENTRY.cbl** — Accepts new order input, calls a validation routine, writes to an order transaction file. Include order total calculation with tax logic.
3. **ORDPROC.cbl** — Batch program that reads the order transaction file, cross-references CUSTMAST via the copybook layout, applies business rules (e.g., "orders over $10,000 require manager approval flag," "reject orders from customers with credit hold status"), and produces an approved/rejected output file.
4. **INVUPDT.cbl** — Updates inventory levels based on approved orders; includes a reorder-point check that flags low stock.
5. **RPTGEN.cbl** — Reads processed files and generates a formatted daily summary report (totals, rejected order count, low stock alerts).
6. **Copybooks** — Realistic fixed-width field layouts (PIC clauses) with COMP-3 fields for monetary values, to reflect real mainframe data typing.
7. **JCL** — Include proper step sequencing, condition codes (COND parameters) between steps, and DD statements referencing the datasets above.

## Technical constraints
- Use COBOL-85 or later syntax (no OO-COBOL needed).
- Include inline comments explaining business logic (not just mechanical comments) so a modernization tool has context to extract business rules.
- Introduce a small amount of realistic legacy messiness: at least one GO TO, one deeply nested PERFORM/IF structure, and one piece of dead code (an unused paragraph) — this is common in real mainframe systems and useful for testing tech-debt detection.
- Add a README.md summarizing the system's purpose, file relationships, and the JCL execution order, as if handing this off to a new team member.

## Output
Generate all files with full content (not placeholders). After generating, give me a one-paragraph summary of the business rules embedded across the programs, so I have a reference to compare against whatever the modernization tool extracts.

---
