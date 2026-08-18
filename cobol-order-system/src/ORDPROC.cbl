       IDENTIFICATION DIVISION.
       PROGRAM-ID. ORDPROC.
      *****************************************************************
      * ORDPROC - Order Processing / Validation Batch Job
      * Reads pending order transactions, cross-references CUSTMAST,
      * applies approval/rejection business rules, writes outputs.
      *****************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ORDER-IN-FILE
               ASSIGN TO ORDPEND
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-IN-STATUS.
           SELECT CUST-FILE
               ASSIGN TO CUSTMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CUST-ID
               FILE STATUS IS WS-CUST-STATUS.
           SELECT APPROVED-FILE
               ASSIGN TO ORDAPPR
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-APPR-STATUS.
           SELECT REJECTED-FILE
               ASSIGN TO ORDREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-REJ-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ORDER-IN-FILE.
           COPY ORDREC.

       FD  CUST-FILE.
           COPY CUSTREC.

       FD  APPROVED-FILE.
       01  APPR-REC                    PIC X(200).

       FD  REJECTED-FILE.
       01  REJ-REC                     PIC X(200).

       WORKING-STORAGE SECTION.
       01  WS-IN-STATUS                PIC X(02).
           88  IN-OK                   VALUE '00'.
           88  IN-EOF                  VALUE '10'.
       01  WS-CUST-STATUS              PIC X(02).
           88  CUST-OK                 VALUE '00'.
           88  CUST-NOT-FOUND          VALUE '23'.
       01  WS-APPR-STATUS              PIC X(02).
       01  WS-REJ-STATUS               PIC X(02).
       01  WS-EOF-FLAG                 PIC X(01) VALUE 'N'.
           88  END-OF-ORDERS           VALUE 'Y'.
       01  WS-DECISION                 PIC X(01).
           88  APPROVE-ORDER           VALUE 'A'.
           88  REJECT-ORDER            VALUE 'R'.
       01  WS-REASON                   PIC X(40).
       01  WS-COUNTS.
           05  WS-APPROVED             PIC 9(05) VALUE ZERO.
           05  WS-REJECTED             PIC 9(05) VALUE ZERO.
           05  WS-MGR-FLAGGED          PIC 9(05) VALUE ZERO.
       01  WS-AVAIL-CREDIT             PIC S9(9)V99 COMP-3.
       01  WS-ORDER-WORK.
           05  WK-ORD-NUMBER           PIC X(10).
           05  WK-ORD-CUST-ID          PIC X(10).
           05  WK-ORD-DATE             PIC X(08).
           05  WK-ORD-ITEM-CODE        PIC X(10).
           05  WK-ORD-ITEM-DESC        PIC X(30).
           05  WK-ORD-QTY              PIC S9(5) COMP-3.
           05  WK-ORD-UNIT-PRICE       PIC S9(7)V99 COMP-3.
           05  WK-ORD-SUBTOTAL         PIC S9(9)V99 COMP-3.
           05  WK-ORD-TAX-AMOUNT       PIC S9(7)V99 COMP-3.
           05  WK-ORD-TOTAL            PIC S9(9)V99 COMP-3.
           05  WK-ORD-SHIP-STATE       PIC X(02).
           05  WK-ORD-STATUS           PIC X(01).
           05  WK-ORD-REJECT-REASON    PIC X(40).
           05  WK-ORD-MGR-APPROVAL     PIC X(01).
           05  WK-ORD-WAREHOUSE        PIC X(04).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS UNTIL END-OF-ORDERS
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           OPEN INPUT ORDER-IN-FILE
           OPEN I-O CUST-FILE
           OPEN OUTPUT APPROVED-FILE
           OPEN OUTPUT REJECTED-FILE
           IF WS-IN-STATUS NOT = '00'
               DISPLAY 'ORDPEND OPEN ERROR: ' WS-IN-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-ORDER.

       2000-PROCESS.
           PERFORM 2500-SAVE-ORDER
           MOVE 'A' TO WS-DECISION
           MOVE SPACES TO WS-REASON
           PERFORM 3000-APPLY-RULES
           IF APPROVE-ORDER
               PERFORM 4000-WRITE-APPROVED
               PERFORM 4500-UPDATE-CUST-BALANCE
               ADD 1 TO WS-APPROVED
           ELSE
               PERFORM 5000-WRITE-REJECTED
               ADD 1 TO WS-REJECTED
           END-IF
           PERFORM 2100-READ-ORDER.

       2100-READ-ORDER.
           READ ORDER-IN-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
               NOT AT END
                   CONTINUE
           END-READ.

       2500-SAVE-ORDER.
           MOVE ORD-NUMBER TO WK-ORD-NUMBER
           MOVE ORD-CUST-ID TO WK-ORD-CUST-ID
           MOVE ORD-DATE TO WK-ORD-DATE
           MOVE ORD-ITEM-CODE TO WK-ORD-ITEM-CODE
           MOVE ORD-ITEM-DESC TO WK-ORD-ITEM-DESC
           MOVE ORD-QTY TO WK-ORD-QTY
           MOVE ORD-UNIT-PRICE TO WK-ORD-UNIT-PRICE
           MOVE ORD-SUBTOTAL TO WK-ORD-SUBTOTAL
           MOVE ORD-TAX-AMOUNT TO WK-ORD-TAX-AMOUNT
           MOVE ORD-TOTAL TO WK-ORD-TOTAL
           MOVE ORD-SHIP-STATE TO WK-ORD-SHIP-STATE
           MOVE ORD-STATUS TO WK-ORD-STATUS
           MOVE ORD-REJECT-REASON TO WK-ORD-REJECT-REASON
           MOVE ORD-MGR-APPROVAL TO WK-ORD-MGR-APPROVAL
           MOVE ORD-WAREHOUSE TO WK-ORD-WAREHOUSE.

      *****************************************************************
      * Nested business rule evaluation (legacy-style deep nesting).
      * Rules: credit hold reject; inactive reject; credit limit;
      * orders over $10,000 require manager approval flag.
      *****************************************************************
       3000-APPLY-RULES.
           MOVE WK-ORD-CUST-ID TO CUST-ID
           READ CUST-FILE
               KEY IS CUST-ID
               INVALID KEY
                   MOVE 'R' TO WS-DECISION
                   MOVE 'CUSTOMER NOT FOUND DURING PROCESSING'
                       TO WS-REASON
                   GO TO 3000-EXIT
           END-READ
           IF CUST-STATUS = 'H'
               MOVE 'R' TO WS-DECISION
               MOVE 'REJECTED - CUSTOMER CREDIT HOLD'
                   TO WS-REASON
           ELSE
               IF CUST-STATUS = 'I'
                   MOVE 'R' TO WS-DECISION
                   MOVE 'REJECTED - INACTIVE CUSTOMER'
                       TO WS-REASON
               ELSE
                   IF CUST-STATUS = 'A'
                       COMPUTE WS-AVAIL-CREDIT =
                           CUST-CREDIT-LIMIT - CUST-CURRENT-BALANCE
                       IF WK-ORD-TOTAL > WS-AVAIL-CREDIT
                           MOVE 'R' TO WS-DECISION
                           MOVE 'REJECTED - EXCEEDS AVAILABLE CREDIT'
                               TO WS-REASON
                       ELSE
      *                    Business Rule: Orders over $10,000 require
      *                    manager approval flag before fulfillment
                           IF WK-ORD-TOTAL > 10000.00
                               IF WK-ORD-MGR-APPROVAL = 'Y'
                                   MOVE 'A' TO WS-DECISION
                                   MOVE SPACES TO WS-REASON
                               ELSE
                                   MOVE 'Y' TO WK-ORD-MGR-APPROVAL
                                   ADD 1 TO WS-MGR-FLAGGED
                                   MOVE 'A' TO WS-DECISION
                                   MOVE 'MGR APPROVAL REQUIRED >$10000'
                                       TO WS-REASON
                               END-IF
                           ELSE
                               MOVE 'A' TO WS-DECISION
                               MOVE SPACES TO WS-REASON
                           END-IF
                       END-IF
                   ELSE
                       MOVE 'R' TO WS-DECISION
                       MOVE 'REJECTED - UNKNOWN CUSTOMER STATUS'
                           TO WS-REASON
                   END-IF
               END-IF
           END-IF.
       3000-EXIT.
           EXIT.

       4000-WRITE-APPROVED.
           INITIALIZE ORDER-RECORD
           MOVE WK-ORD-NUMBER TO ORD-NUMBER
           MOVE WK-ORD-CUST-ID TO ORD-CUST-ID
           MOVE WK-ORD-DATE TO ORD-DATE
           MOVE WK-ORD-ITEM-CODE TO ORD-ITEM-CODE
           MOVE WK-ORD-ITEM-DESC TO ORD-ITEM-DESC
           MOVE WK-ORD-QTY TO ORD-QTY
           MOVE WK-ORD-UNIT-PRICE TO ORD-UNIT-PRICE
           MOVE WK-ORD-SUBTOTAL TO ORD-SUBTOTAL
           MOVE WK-ORD-TAX-AMOUNT TO ORD-TAX-AMOUNT
           MOVE WK-ORD-TOTAL TO ORD-TOTAL
           MOVE WK-ORD-SHIP-STATE TO ORD-SHIP-STATE
           MOVE 'A' TO ORD-STATUS
           MOVE WS-REASON TO ORD-REJECT-REASON
           MOVE WK-ORD-MGR-APPROVAL TO ORD-MGR-APPROVAL
           MOVE WK-ORD-WAREHOUSE TO ORD-WAREHOUSE
           WRITE APPR-REC FROM ORDER-RECORD.

       4500-UPDATE-CUST-BALANCE.
      *    Business Rule: Approved order amount added to customer balance
           ADD WK-ORD-TOTAL TO CUST-CURRENT-BALANCE
           ADD WK-ORD-TOTAL TO CUST-YTD-ORDERS
           MOVE WK-ORD-DATE TO CUST-LAST-ORDER-DATE
           REWRITE CUSTOMER-RECORD
           IF NOT CUST-OK
               DISPLAY 'CUST BALANCE UPDATE FAILED: ' CUST-ID
           END-IF.

       5000-WRITE-REJECTED.
           INITIALIZE ORDER-RECORD
           MOVE WK-ORD-NUMBER TO ORD-NUMBER
           MOVE WK-ORD-CUST-ID TO ORD-CUST-ID
           MOVE WK-ORD-DATE TO ORD-DATE
           MOVE WK-ORD-ITEM-CODE TO ORD-ITEM-CODE
           MOVE WK-ORD-ITEM-DESC TO ORD-ITEM-DESC
           MOVE WK-ORD-QTY TO ORD-QTY
           MOVE WK-ORD-UNIT-PRICE TO ORD-UNIT-PRICE
           MOVE WK-ORD-SUBTOTAL TO ORD-SUBTOTAL
           MOVE WK-ORD-TAX-AMOUNT TO ORD-TAX-AMOUNT
           MOVE WK-ORD-TOTAL TO ORD-TOTAL
           MOVE WK-ORD-SHIP-STATE TO ORD-SHIP-STATE
           MOVE 'R' TO ORD-STATUS
           MOVE WS-REASON TO ORD-REJECT-REASON
           MOVE WK-ORD-MGR-APPROVAL TO ORD-MGR-APPROVAL
           MOVE WK-ORD-WAREHOUSE TO ORD-WAREHOUSE
           WRITE REJ-REC FROM ORDER-RECORD.

       9000-TERMINATE.
           CLOSE ORDER-IN-FILE
           CLOSE CUST-FILE
           CLOSE APPROVED-FILE
           CLOSE REJECTED-FILE
           DISPLAY 'ORDPROC COMPLETE - APPROVED=' WS-APPROVED
               ' REJECTED=' WS-REJECTED
               ' MGR-FLAG=' WS-MGR-FLAGGED
           IF WS-REJECTED > ZERO
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE ZERO TO RETURN-CODE
           END-IF.

      *****************************************************************
      * Dead code - old fax notification path, never called.
      *****************************************************************
       9900-FAX-MGR-ALERT.
           DISPLAY 'FAX MANAGER ALERT - LEGACY PATH UNUSED'
           MOVE ZERO TO RETURN-CODE.
