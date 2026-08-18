# Customer Order Management System
## Overview

Legacy z/OS batch application for a fictional retail company. It maintains customer masters, accepts orders, validates/approves them against credit and status rules, updates inventory, and produces an end-of-day summary report.

Intended as **realistic sample input** for mainframe modernization assessment tools (e.g. AWS Transform): dependency mapping, business-rule extraction, and complexity / tech-debt scoring.

## Directory layout

```
cobol-order-system/
  src/           COBOL programs
  copybooks/     Shared record layouts (PIC / COMP-3)
  jcl/           Batch job streams
  data/          Sample fixed-width input
  README.md
```

## Programs

| Program   | Role |
|-----------|------|
| CUSTMAST  | Customer master maintenance (Add / Update / Inquire) |
| ORDENTRY  | Order entry with tax calculation and validation |
| ORDPROC   | Batch order approval/rejection against customer credit |
| INVUPDT   | Inventory deduction and reorder-point alerts |
| RPTGEN    | Daily summary report |

## Copybooks

| Copybook | Record |
|----------|--------|
| CUSTREC  | Customer master (status, credit limit, balances) |
| ORDREC   | Order transaction (amounts, status, mgr flag) |
| INVREC   | Inventory master (qty, reorder point, low-stock flag) |

## File relationships

```
CUSTTRAN -----------> CUSTMAST -----------> CUSTMAST (VSAM)
                                              ^
ORDIN -------------> ORDENTRY -------------> ORDPEND
                       |                      |
                    CUSTMAST / INVMAST         v
                                           ORDPROC -----> ORDAPPR -----> INVUPDT -----> INVMAST
                                              |              |              |
                                              v              v              v
                                           ORDREJ         DAYRPT <----- LOWSTOCK
                                                              ^
                                                           RPTGEN
```

## JCL execution order

### Daily batch — `jcl/ORDDAILY.jcl`

1. **ORDPROC** — validate pending orders → approved / rejected  
2. **INVUPDT** — update inventory from approved (`COND=(8,LE,ORDPROC)`)  
3. **RPTGEN** — daily summary (`COND` on ORDPROC and INVUPDT)  
4. **CLEANUP** — delete pending file if all prior steps RC = 0  

### Customer maintenance — `jcl/CUSTMNT.jcl`

1. **CUSTMAST** — apply customer maintenance transactions  
2. **ORDENTRY** — optional order entry if CUSTMAST RC < 8  

## Business rules (quick reference)

See the one-paragraph summary produced with this sample, or comments marked `Business Rule:` inside the COBOL sources.

## Legacy characteristics (intentional)

- `GO TO` exits in validation paragraphs (CUSTMAST, ORDENTRY, ORDPROC, INVUPDT)  
- Deeply nested `IF` structure in ORDPROC `3000-APPLY-RULES`  
- Dead (unreachable) paragraphs: `9900-CREDIT-BUREAU-CHECK`, `9900-FAX-MGR-ALERT`, `9900-CYCLE-COUNT-SYNC`  

## Sample data

- `data/sample-customers.txt` — five customers (Active, Hold, Inactive, high-credit)  
- `data/sample-orders.txt` — five order-entry rows covering happy path and rule violations  

Monetary fields in production use **COMP-3**; sample text files use zoned/display values for readability in assessment tooling.
