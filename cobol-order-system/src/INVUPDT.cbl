       IDENTIFICATION DIVISION.
       PROGRAM-ID. INVUPDT.
      *****************************************************************
      * INVUPDT - Inventory Update Program
      * Reduces on-hand quantity for approved orders, allocates stock,
      * and flags items at or below reorder point.
      *****************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT APPROVED-FILE
               ASSIGN TO ORDAPPR
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-APPR-STATUS.
           SELECT INV-FILE
               ASSIGN TO INVMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS INV-ITEM-CODE
               FILE STATUS IS WS-INV-STATUS.
           SELECT LOWSTOCK-FILE
               ASSIGN TO LOWSTOCK
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-LOW-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  APPROVED-FILE.
           COPY ORDREC.

       FD  INV-FILE.
           COPY INVREC.

       FD  LOWSTOCK-FILE.
       01  LOW-LINE                    PIC X(100).

       WORKING-STORAGE SECTION.
       01  WS-APPR-STATUS              PIC X(02).
           88  APPR-OK                 VALUE '00'.
           88  APPR-EOF                VALUE '10'.
       01  WS-INV-STATUS               PIC X(02).
           88  INV-OK                  VALUE '00'.
           88  INV-NOT-FOUND           VALUE '23'.
       01  WS-LOW-STATUS               PIC X(02).
       01  WS-EOF-FLAG                 PIC X(01) VALUE 'N'.
           88  END-OF-APPROVED         VALUE 'Y'.
       01  WS-COUNTS.
           05  WS-UPDATED              PIC 9(05) VALUE ZERO.
           05  WS-SKIPPED              PIC 9(05) VALUE ZERO.
           05  WS-LOW-STOCK            PIC 9(05) VALUE ZERO.
       01  WS-TODAY                    PIC X(08).
       01  WS-AVAIL-AFTER              PIC S9(7) COMP-3.
       01  WS-EDIT-QOH                 PIC ZZZ,ZZ9.
       01  WS-EDIT-ROP                 PIC ZZ,ZZ9.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS UNTIL END-OF-APPROVED
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           ACCEPT WS-TODAY FROM DATE YYYYMMDD
           OPEN INPUT APPROVED-FILE
           OPEN I-O INV-FILE
           OPEN OUTPUT LOWSTOCK-FILE
           IF WS-APPR-STATUS NOT = '00'
               DISPLAY 'ORDAPPR OPEN ERROR: ' WS-APPR-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-APPROVED.

       2000-PROCESS.
           PERFORM 3000-UPDATE-INVENTORY
           PERFORM 2100-READ-APPROVED.

       2100-READ-APPROVED.
           READ APPROVED-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
               NOT AT END
                   CONTINUE
           END-READ.

      *****************************************************************
      * Business Rule: Deduct order qty from on-hand; if remaining
      * on-hand <= reorder point, set low-stock flag and write alert.
      * Discontinued / hold items are skipped (not updated).
      *****************************************************************
       3000-UPDATE-INVENTORY.
           MOVE ORD-ITEM-CODE TO INV-ITEM-CODE
           READ INV-FILE
               KEY IS INV-ITEM-CODE
               INVALID KEY
                   DISPLAY 'ITEM NOT FOUND: ' ORD-ITEM-CODE
                   ADD 1 TO WS-SKIPPED
                   GO TO 3000-EXIT
           END-READ
           IF INV-STATUS = 'D' OR INV-STATUS = 'H'
               DISPLAY 'ITEM NOT ORDERABLE: ' INV-ITEM-CODE
                   ' STATUS=' INV-STATUS
               ADD 1 TO WS-SKIPPED
               GO TO 3000-EXIT
           END-IF
           IF ORD-QTY > INV-QTY-ON-HAND
      *        Business Rule: Do not drive inventory negative; skip
               DISPLAY 'OVERSELL BLOCKED: ' INV-ITEM-CODE
               ADD 1 TO WS-SKIPPED
               GO TO 3000-EXIT
           END-IF
           SUBTRACT ORD-QTY FROM INV-QTY-ON-HAND
           IF INV-QTY-ALLOCATED >= ORD-QTY
               SUBTRACT ORD-QTY FROM INV-QTY-ALLOCATED
           ELSE
               MOVE ZERO TO INV-QTY-ALLOCATED
           END-IF
           MOVE WS-TODAY TO INV-LAST-ISSUE-DATE
           COMPUTE WS-AVAIL-AFTER = INV-QTY-ON-HAND
      *    Business Rule: Reorder-point check — flag low stock
           IF WS-AVAIL-AFTER <= INV-REORDER-POINT
               MOVE 'Y' TO INV-LOW-STOCK-FLAG
               PERFORM 4000-WRITE-LOW-STOCK
               ADD 1 TO WS-LOW-STOCK
           ELSE
               MOVE 'N' TO INV-LOW-STOCK-FLAG
           END-IF
           REWRITE INVENTORY-RECORD
           IF INV-OK
               ADD 1 TO WS-UPDATED
           ELSE
               DISPLAY 'INV REWRITE FAILED: ' INV-ITEM-CODE
               ADD 1 TO WS-SKIPPED
           END-IF.
       3000-EXIT.
           EXIT.

       4000-WRITE-LOW-STOCK.
           MOVE INV-QTY-ON-HAND TO WS-EDIT-QOH
           MOVE INV-REORDER-POINT TO WS-EDIT-ROP
           STRING INV-ITEM-CODE '|' INV-ITEM-DESC '|'
               'WH=' INV-WAREHOUSE '|'
               'QOH=' WS-EDIT-QOH '|'
               'ROP=' WS-EDIT-ROP '|'
               'LOW STOCK ALERT'
               DELIMITED BY SIZE INTO LOW-LINE
           WRITE LOW-LINE.

       9000-TERMINATE.
           CLOSE APPROVED-FILE
           CLOSE INV-FILE
           CLOSE LOWSTOCK-FILE
           DISPLAY 'INVUPDT COMPLETE - UPDATED=' WS-UPDATED
               ' SKIPPED=' WS-SKIPPED
               ' LOWSTOCK=' WS-LOW-STOCK
           IF WS-SKIPPED > ZERO
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE ZERO TO RETURN-CODE
           END-IF.

      *****************************************************************
      * Dead code - abandoned cycle-count sync routine.
      *****************************************************************
       9900-CYCLE-COUNT-SYNC.
           DISPLAY 'CYCLE COUNT SYNC NOT CONNECTED'
           MOVE ZERO TO RETURN-CODE.
