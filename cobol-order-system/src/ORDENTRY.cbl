       IDENTIFICATION DIVISION.
       PROGRAM-ID. ORDENTRY.
      *****************************************************************
      * ORDENTRY - Order Entry Program
      * Accepts new order transactions, validates, calculates tax,
      * and writes pending orders to the order transaction file.
      *****************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ORDER-IN-FILE
               ASSIGN TO ORDIN
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-IN-STATUS.
           SELECT ORDER-OUT-FILE
               ASSIGN TO ORDOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-OUT-STATUS.
           SELECT CUST-FILE
               ASSIGN TO CUSTMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CUST-ID
               FILE STATUS IS WS-CUST-STATUS.
           SELECT INV-FILE
               ASSIGN TO INVMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS INV-ITEM-CODE
               FILE STATUS IS WS-INV-STATUS.
           SELECT ERR-FILE
               ASSIGN TO ORDERR
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ERR-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ORDER-IN-FILE.
       01  ORDER-IN-REC.
           05  IN-ORD-NUMBER           PIC X(10).
           05  IN-ORD-CUST-ID          PIC X(10).
           05  IN-ORD-DATE             PIC X(08).
           05  IN-ORD-ITEM-CODE        PIC X(10).
           05  IN-ORD-QTY              PIC 9(05).
           05  IN-ORD-SHIP-STATE       PIC X(02).
           05  IN-ORD-WAREHOUSE        PIC X(04).

       FD  ORDER-OUT-FILE.
       COPY ORDREC.

       FD  CUST-FILE.
       COPY CUSTREC.

       FD  INV-FILE.
       COPY INVREC.

       FD  ERR-FILE.
       01  ERR-LINE                    PIC X(100).

       WORKING-STORAGE SECTION.
       01  WS-IN-STATUS                PIC X(02).
           88  IN-OK                   VALUE '00'.
           88  IN-EOF                  VALUE '10'.
       01  WS-OUT-STATUS               PIC X(02).
       01  WS-CUST-STATUS              PIC X(02).
           88  CUST-OK                 VALUE '00'.
           88  CUST-NOT-FOUND          VALUE '23'.
       01  WS-INV-STATUS               PIC X(02).
           88  INV-OK                  VALUE '00'.
           88  INV-NOT-FOUND           VALUE '23'.
       01  WS-ERR-STATUS               PIC X(02).
       01  WS-EOF-FLAG                 PIC X(01) VALUE 'N'.
           88  END-OF-INPUT            VALUE 'Y'.
       01  WS-VALID-FLAG               PIC X(01) VALUE 'Y'.
           88  ORDER-VALID             VALUE 'Y'.
           88  ORDER-INVALID           VALUE 'N'.
       01  WS-ERR-MSG                  PIC X(60).
       01  WS-COUNTS.
           05  WS-ACCEPTED             PIC 9(05) VALUE ZERO.
           05  WS-REJECTED             PIC 9(05) VALUE ZERO.
       01  WS-TAX-RATE                 PIC V9999 VALUE ZERO.
       01  WS-WORK-SUBTOTAL            PIC S9(9)V99 COMP-3.
       01  WS-WORK-TAX                 PIC S9(7)V99 COMP-3.
       01  WS-WORK-TOTAL               PIC S9(9)V99 COMP-3.
       01  WS-AVAIL-QTY                PIC S9(7) COMP-3.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS-ORDERS UNTIL END-OF-INPUT
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           OPEN INPUT ORDER-IN-FILE
           OPEN OUTPUT ORDER-OUT-FILE
           OPEN INPUT CUST-FILE
           OPEN INPUT INV-FILE
           OPEN OUTPUT ERR-FILE
           IF WS-IN-STATUS NOT = '00'
               DISPLAY 'ORDIN OPEN ERROR: ' WS-IN-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-INPUT.

       2000-PROCESS-ORDERS.
           MOVE 'Y' TO WS-VALID-FLAG
           MOVE SPACES TO WS-ERR-MSG
           PERFORM 3000-VALIDATE-ORDER
           IF ORDER-VALID
               PERFORM 4000-CALC-TOTALS
               PERFORM 5000-WRITE-ORDER
               ADD 1 TO WS-ACCEPTED
           ELSE
               PERFORM 6000-WRITE-ERROR
               ADD 1 TO WS-REJECTED
           END-IF
           PERFORM 2100-READ-INPUT.

       2100-READ-INPUT.
           READ ORDER-IN-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
               NOT AT END
                   CONTINUE
           END-READ.

      *****************************************************************
      * Validation: customer must exist and be Active; inactive and
      * credit-hold customers cannot place new orders. Item must exist
      * and have sufficient available quantity.
      *****************************************************************
       3000-VALIDATE-ORDER.
           IF IN-ORD-NUMBER = SPACES
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'ORDER NUMBER REQUIRED' TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF
           IF IN-ORD-QTY = ZERO OR IN-ORD-QTY IS NOT NUMERIC
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'ORDER QUANTITY MUST BE NUMERIC AND > ZERO'
                   TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF
           MOVE IN-ORD-CUST-ID TO CUST-ID
           READ CUST-FILE
               KEY IS CUST-ID
               INVALID KEY
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'CUSTOMER NOT FOUND ON MASTER'
                       TO WS-ERR-MSG
                   GO TO 3000-EXIT
           END-READ
      *    Business Rule: Inactive customers cannot place new orders
           IF CUST-STATUS = 'I'
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'INACTIVE CUSTOMER - ORDER REJECTED'
                   TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF
      *    Business Rule: Credit hold customers cannot place new orders
           IF CUST-STATUS = 'H'
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'CUSTOMER ON CREDIT HOLD - ORDER REJECTED'
                   TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF
           MOVE IN-ORD-ITEM-CODE TO INV-ITEM-CODE
           READ INV-FILE
               KEY IS INV-ITEM-CODE
               INVALID KEY
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'ITEM CODE NOT FOUND IN INVENTORY'
                       TO WS-ERR-MSG
                   GO TO 3000-EXIT
           END-READ
           IF INV-STATUS = 'D'
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'ITEM DISCONTINUED - CANNOT ORDER'
                   TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF
           COMPUTE WS-AVAIL-QTY =
               INV-QTY-ON-HAND - INV-QTY-ALLOCATED
           IF IN-ORD-QTY > WS-AVAIL-QTY
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'INSUFFICIENT AVAILABLE INVENTORY'
                   TO WS-ERR-MSG
               GO TO 3000-EXIT
           END-IF.
       3000-EXIT.
           EXIT.

      *****************************************************************
      * Tax logic by ship-to state (simplified state tax table).
      * CA=7.25%, NY=8.00%, TX=6.25%, FL=6.00%, else default 5.00%.
      * Order total = subtotal + tax.
      *****************************************************************
       4000-CALC-TOTALS.
           COMPUTE WS-WORK-SUBTOTAL =
               IN-ORD-QTY * INV-UNIT-PRICE
           EVALUATE IN-ORD-SHIP-STATE
               WHEN 'CA'
                   MOVE 0.0725 TO WS-TAX-RATE
               WHEN 'NY'
                   MOVE 0.0800 TO WS-TAX-RATE
               WHEN 'TX'
                   MOVE 0.0625 TO WS-TAX-RATE
               WHEN 'FL'
                   MOVE 0.0600 TO WS-TAX-RATE
               WHEN OTHER
                   MOVE 0.0500 TO WS-TAX-RATE
           END-EVALUATE
           COMPUTE WS-WORK-TAX ROUNDED =
               WS-WORK-SUBTOTAL * WS-TAX-RATE
           COMPUTE WS-WORK-TOTAL =
               WS-WORK-SUBTOTAL + WS-WORK-TAX.

       5000-WRITE-ORDER.
           INITIALIZE ORDER-RECORD
           MOVE IN-ORD-NUMBER TO ORD-NUMBER
           MOVE IN-ORD-CUST-ID TO ORD-CUST-ID
           MOVE IN-ORD-DATE TO ORD-DATE
           MOVE IN-ORD-ITEM-CODE TO ORD-ITEM-CODE
           MOVE INV-ITEM-DESC TO ORD-ITEM-DESC
           MOVE IN-ORD-QTY TO ORD-QTY
           MOVE INV-UNIT-PRICE TO ORD-UNIT-PRICE
           MOVE WS-WORK-SUBTOTAL TO ORD-SUBTOTAL
           MOVE WS-WORK-TAX TO ORD-TAX-AMOUNT
           MOVE WS-WORK-TOTAL TO ORD-TOTAL
           MOVE IN-ORD-SHIP-STATE TO ORD-SHIP-STATE
           MOVE 'P' TO ORD-STATUS
           MOVE SPACES TO ORD-REJECT-REASON
           MOVE 'N' TO ORD-MGR-APPROVAL
           MOVE IN-ORD-WAREHOUSE TO ORD-WAREHOUSE
           WRITE ORDER-RECORD.

       6000-WRITE-ERROR.
           STRING IN-ORD-NUMBER '|' IN-ORD-CUST-ID '|'
               WS-ERR-MSG
               DELIMITED BY SIZE INTO ERR-LINE
           WRITE ERR-LINE.

       9000-TERMINATE.
           CLOSE ORDER-IN-FILE
           CLOSE ORDER-OUT-FILE
           CLOSE CUST-FILE
           CLOSE INV-FILE
           CLOSE ERR-FILE
           DISPLAY 'ORDENTRY COMPLETE - ACCEPTED=' WS-ACCEPTED
               ' REJECTED=' WS-REJECTED
           IF WS-REJECTED > ZERO
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE ZERO TO RETURN-CODE
           END-IF.
