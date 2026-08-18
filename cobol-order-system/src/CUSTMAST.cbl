       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTMAST.
      *****************************************************************
      * CUSTMAST - Customer Master Maintenance
      * Functions: Add (A), Update (U), Inquire (I) customers
      * Maintains VSAM-style customer master file CUSTMAST
      *****************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUSTOMER-FILE
               ASSIGN TO CUSTMAST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS CUST-ID
               FILE STATUS IS WS-CUST-STATUS.
           SELECT TRANS-FILE
               ASSIGN TO CUSTTRAN
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TRAN-STATUS.
           SELECT REPORT-FILE
               ASSIGN TO CUSTRPT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  CUSTOMER-FILE.
       COPY CUSTREC.

       FD  TRANS-FILE.
       01  TRAN-RECORD.
           05  TRAN-ACTION             PIC X(01).
           05  TRAN-CUST-ID            PIC X(10).
           05  TRAN-CUST-NAME          PIC X(40).
           05  TRAN-ADDR1              PIC X(40).
           05  TRAN-ADDR2              PIC X(40).
           05  TRAN-CITY               PIC X(25).
           05  TRAN-STATE              PIC X(02).
           05  TRAN-ZIP                PIC X(10).
           05  TRAN-PHONE              PIC X(15).
           05  TRAN-STATUS             PIC X(01).
           05  TRAN-CREDIT-LIMIT       PIC S9(9)V99 COMP-3.
           05  TRAN-SALES-REP          PIC X(08).

       FD  REPORT-FILE.
       01  RPT-LINE                    PIC X(132).

       WORKING-STORAGE SECTION.
       01  WS-CUST-STATUS              PIC X(02).
           88  CUST-OK                 VALUE '00'.
           88  CUST-EOF                VALUE '10'.
           88  CUST-NOT-FOUND          VALUE '23'.
           88  CUST-DUP-KEY            VALUE '22'.
       01  WS-TRAN-STATUS              PIC X(02).
           88  TRAN-OK                 VALUE '00'.
           88  TRAN-EOF                VALUE '10'.
       01  WS-RPT-STATUS               PIC X(02).
       01  WS-EOF-FLAG                 PIC X(01) VALUE 'N'.
           88  END-OF-TRANS            VALUE 'Y'.
       01  WS-VALID-FLAG               PIC X(01) VALUE 'Y'.
           88  RECORD-VALID            VALUE 'Y'.
           88  RECORD-INVALID          VALUE 'N'.
       01  WS-ERROR-MSG                PIC X(60).
       01  WS-COUNTS.
           05  WS-ADDED                PIC 9(05) VALUE ZERO.
           05  WS-UPDATED              PIC 9(05) VALUE ZERO.
           05  WS-INQUIRED             PIC 9(05) VALUE ZERO.
           05  WS-REJECTED             PIC 9(05) VALUE ZERO.
       01  WS-TODAY                    PIC X(08).
       01  WS-HDR1                     PIC X(132) VALUE
           'CUSTOMER MASTER MAINTENANCE REPORT'.
       01  WS-HDR2                     PIC X(132) VALUE
           'ACTION CUST-ID    NAME                                     RESULT'.
       01  WS-DETAIL                   PIC X(132).
       01  WS-EDIT-LIMIT               PIC ZZZ,ZZZ,ZZ9.99.
       01  WS-EDIT-BAL                 PIC ZZZ,ZZZ,ZZ9.99.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS-TRANS UNTIL END-OF-TRANS
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           ACCEPT WS-TODAY FROM DATE YYYYMMDD
           OPEN I-O CUSTOMER-FILE
           IF NOT CUST-OK
               DISPLAY 'CUSTMAST OPEN ERROR: ' WS-CUST-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN INPUT TRANS-FILE
           IF NOT TRAN-OK
               DISPLAY 'CUSTTRAN OPEN ERROR: ' WS-TRAN-STATUS
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN OUTPUT REPORT-FILE
           WRITE RPT-LINE FROM WS-HDR1
           WRITE RPT-LINE FROM WS-HDR2
           PERFORM 2100-READ-TRANS.

       2000-PROCESS-TRANS.
           MOVE 'Y' TO WS-VALID-FLAG
           MOVE SPACES TO WS-ERROR-MSG
           EVALUATE TRAN-ACTION
               WHEN 'A'
                   PERFORM 3000-ADD-CUSTOMER
               WHEN 'U'
                   PERFORM 4000-UPDATE-CUSTOMER
               WHEN 'I'
                   PERFORM 5000-INQUIRE-CUSTOMER
               WHEN OTHER
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'INVALID ACTION CODE - MUST BE A/U/I'
                       TO WS-ERROR-MSG
                   ADD 1 TO WS-REJECTED
           END-EVALUATE
           PERFORM 8000-WRITE-DETAIL
           PERFORM 2100-READ-TRANS.

       2100-READ-TRANS.
           READ TRANS-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
               NOT AT END
                   CONTINUE
           END-READ.

      *****************************************************************
      * Business Rule: New customers must pass ID format, credit limit
      * floor ($500), and status must be Active (A) on add.
      *****************************************************************
       3000-ADD-CUSTOMER.
           PERFORM 6000-VALIDATE-CUST-ID
           IF RECORD-INVALID
               ADD 1 TO WS-REJECTED
               GO TO 3000-EXIT
           END-IF
      *    Business Rule: Minimum credit limit is $500.00 for new accounts
           IF TRAN-CREDIT-LIMIT < 500.00
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'CREDIT LIMIT BELOW MINIMUM $500.00'
                   TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
               GO TO 3000-EXIT
           END-IF
      *    Business Rule: New customers must start as Active status
           IF TRAN-STATUS NOT = 'A'
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'NEW CUSTOMER STATUS MUST BE ACTIVE (A)'
                   TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
               GO TO 3000-EXIT
           END-IF
           INITIALIZE CUSTOMER-RECORD
           MOVE TRAN-CUST-ID TO CUST-ID
           MOVE TRAN-CUST-NAME TO CUST-NAME
           MOVE TRAN-ADDR1 TO CUST-ADDR-LINE1
           MOVE TRAN-ADDR2 TO CUST-ADDR-LINE2
           MOVE TRAN-CITY TO CUST-CITY
           MOVE TRAN-STATE TO CUST-STATE
           MOVE TRAN-ZIP TO CUST-ZIP
           MOVE TRAN-PHONE TO CUST-PHONE
           MOVE TRAN-STATUS TO CUST-STATUS
           MOVE TRAN-CREDIT-LIMIT TO CUST-CREDIT-LIMIT
           MOVE ZERO TO CUST-CURRENT-BALANCE
           MOVE ZERO TO CUST-YTD-ORDERS
           MOVE SPACES TO CUST-LAST-ORDER-DATE
           MOVE WS-TODAY TO CUST-ACCT-OPEN-DATE
           MOVE TRAN-SALES-REP TO CUST-SALES-REP
           WRITE CUSTOMER-RECORD
           IF CUST-DUP-KEY
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'CUSTOMER ID ALREADY EXISTS'
                   TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
           ELSE
               IF CUST-OK
                   ADD 1 TO WS-ADDED
                   MOVE 'ADDED OK' TO WS-ERROR-MSG
               ELSE
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'WRITE FAILED' TO WS-ERROR-MSG
                   ADD 1 TO WS-REJECTED
               END-IF
           END-IF.
       3000-EXIT.
           EXIT.

      *****************************************************************
      * Business Rule: Credit limit cannot be reduced below current
      * balance. Inactive customers cannot have credit limit increased.
      *****************************************************************
       4000-UPDATE-CUSTOMER.
           PERFORM 6000-VALIDATE-CUST-ID
           IF RECORD-INVALID
               ADD 1 TO WS-REJECTED
               GO TO 4000-EXIT
           END-IF
           MOVE TRAN-CUST-ID TO CUST-ID
           READ CUSTOMER-FILE
               KEY IS CUST-ID
               INVALID KEY
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'CUSTOMER NOT FOUND FOR UPDATE'
                       TO WS-ERROR-MSG
                   ADD 1 TO WS-REJECTED
                   GO TO 4000-EXIT
           END-READ
      *    Business Rule: Cannot set credit limit below outstanding balance
           IF TRAN-CREDIT-LIMIT < CUST-CURRENT-BALANCE
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'CREDIT LIMIT CANNOT BE BELOW CURRENT BALANCE'
                   TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
               GO TO 4000-EXIT
           END-IF
      *    Business Rule: Inactive customers cannot receive credit increases
           IF CUST-STATUS = 'I'
               AND TRAN-CREDIT-LIMIT > CUST-CREDIT-LIMIT
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'INACTIVE CUSTOMER - CREDIT INCREASE DENIED'
                   TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
               GO TO 4000-EXIT
           END-IF
           IF TRAN-CUST-NAME NOT = SPACES
               MOVE TRAN-CUST-NAME TO CUST-NAME
           END-IF
           IF TRAN-ADDR1 NOT = SPACES
               MOVE TRAN-ADDR1 TO CUST-ADDR-LINE1
           END-IF
           IF TRAN-CITY NOT = SPACES
               MOVE TRAN-CITY TO CUST-CITY
           END-IF
           IF TRAN-STATE NOT = SPACES
               MOVE TRAN-STATE TO CUST-STATE
           END-IF
           IF TRAN-ZIP NOT = SPACES
               MOVE TRAN-ZIP TO CUST-ZIP
           END-IF
           IF TRAN-PHONE NOT = SPACES
               MOVE TRAN-PHONE TO CUST-PHONE
           END-IF
           IF TRAN-STATUS NOT = SPACES
               MOVE TRAN-STATUS TO CUST-STATUS
           END-IF
           MOVE TRAN-CREDIT-LIMIT TO CUST-CREDIT-LIMIT
           IF TRAN-SALES-REP NOT = SPACES
               MOVE TRAN-SALES-REP TO CUST-SALES-REP
           END-IF
           REWRITE CUSTOMER-RECORD
           IF CUST-OK
               ADD 1 TO WS-UPDATED
               MOVE 'UPDATED OK' TO WS-ERROR-MSG
           ELSE
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'REWRITE FAILED' TO WS-ERROR-MSG
               ADD 1 TO WS-REJECTED
           END-IF.
       4000-EXIT.
           EXIT.

       5000-INQUIRE-CUSTOMER.
           PERFORM 6000-VALIDATE-CUST-ID
           IF RECORD-INVALID
               ADD 1 TO WS-REJECTED
               GO TO 5000-EXIT
           END-IF
           MOVE TRAN-CUST-ID TO CUST-ID
           READ CUSTOMER-FILE
               KEY IS CUST-ID
               INVALID KEY
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'CUSTOMER NOT FOUND'
                       TO WS-ERROR-MSG
                   ADD 1 TO WS-REJECTED
                   GO TO 5000-EXIT
           END-READ
           MOVE CUST-CREDIT-LIMIT TO WS-EDIT-LIMIT
           MOVE CUST-CURRENT-BALANCE TO WS-EDIT-BAL
           STRING 'FOUND ST=' CUST-STATUS
               ' LIM=' WS-EDIT-LIMIT
               ' BAL=' WS-EDIT-BAL
               DELIMITED BY SIZE INTO WS-ERROR-MSG
           ADD 1 TO WS-INQUIRED.
       5000-EXIT.
           EXIT.

      *****************************************************************
      * Business Rule: Customer ID must be 10 chars, first 3 numeric
      * region code (001-999), remaining alphanumeric, no spaces.
      *****************************************************************
       6000-VALIDATE-CUST-ID.
           IF TRAN-CUST-ID = SPACES
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'CUSTOMER ID REQUIRED' TO WS-ERROR-MSG
           ELSE
               IF TRAN-CUST-ID(1:3) IS NOT NUMERIC
                   MOVE 'N' TO WS-VALID-FLAG
                   MOVE 'CUST ID REGION CODE (POS 1-3) MUST BE NUMERIC'
                       TO WS-ERROR-MSG
               ELSE
                   IF TRAN-CUST-ID(1:3) = '000'
                       MOVE 'N' TO WS-VALID-FLAG
                       MOVE 'CUST ID REGION CODE CANNOT BE 000'
                           TO WS-ERROR-MSG
                   END-IF
               END-IF
           END-IF.

       8000-WRITE-DETAIL.
           STRING TRAN-ACTION ' '
               TRAN-CUST-ID ' '
               TRAN-CUST-NAME(1:30) ' '
               WS-ERROR-MSG
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL.

       9000-TERMINATE.
           CLOSE CUSTOMER-FILE
           CLOSE TRANS-FILE
           CLOSE REPORT-FILE
           DISPLAY 'CUSTMAST COMPLETE - ADDED=' WS-ADDED
               ' UPDATED=' WS-UPDATED
               ' INQ=' WS-INQUIRED
               ' REJ=' WS-REJECTED
           IF WS-REJECTED > ZERO
               MOVE 4 TO RETURN-CODE
           ELSE
               MOVE ZERO TO RETURN-CODE
           END-IF.

      *****************************************************************
      * Dead code - legacy credit bureau interface never wired up.
      * Left for modernization / tech-debt detection testing.
      *****************************************************************
       9900-CREDIT-BUREAU-CHECK.
           DISPLAY 'CREDIT BUREAU CHECK NOT IMPLEMENTED'
           MOVE ZERO TO RETURN-CODE.
