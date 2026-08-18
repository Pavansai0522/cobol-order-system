       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPTGEN.
      *****************************************************************
      * RPTGEN - End-of-Day Report Generation
      * Reads approved, rejected, and low-stock files; produces a
      * formatted daily summary report for operations.
      *****************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT APPROVED-FILE
               ASSIGN TO ORDAPPR
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-APPR-STATUS.
           SELECT REJECTED-FILE
               ASSIGN TO ORDREJ
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-REJ-STATUS.
           SELECT LOWSTOCK-FILE
               ASSIGN TO LOWSTOCK
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-LOW-STATUS.
           SELECT REPORT-FILE
               ASSIGN TO DAYRPT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  APPROVED-FILE.
           COPY ORDREC.

       FD  REJECTED-FILE.
           COPY ORDREC.

       FD  LOWSTOCK-FILE.
       01  LOW-LINE                    PIC X(100).

       FD  REPORT-FILE.
       01  RPT-LINE                    PIC X(132).

       WORKING-STORAGE SECTION.
       01  WS-APPR-STATUS              PIC X(02).
           88  APPR-OK                 VALUE '00'.
           88  APPR-EOF                VALUE '10'.
       01  WS-REJ-STATUS               PIC X(02).
           88  REJ-OK                  VALUE '00'.
           88  REJ-EOF                 VALUE '10'.
       01  WS-LOW-STATUS               PIC X(02).
           88  LOW-OK                  VALUE '00'.
           88  LOW-EOF                 VALUE '10'.
       01  WS-RPT-STATUS               PIC X(02).
       01  WS-EOF-APPR                 PIC X(01) VALUE 'N'.
           88  END-APPR                VALUE 'Y'.
       01  WS-EOF-REJ                  PIC X(01) VALUE 'N'.
           88  END-REJ                 VALUE 'Y'.
       01  WS-EOF-LOW                  PIC X(01) VALUE 'N'.
           88  END-LOW                 VALUE 'Y'.
       01  WS-TODAY                    PIC X(08).
       01  WS-TOTALS.
           05  WS-APPR-COUNT           PIC 9(05) VALUE ZERO.
           05  WS-REJ-COUNT            PIC 9(05) VALUE ZERO.
           05  WS-LOW-COUNT            PIC 9(05) VALUE ZERO.
           05  WS-APPR-DOLLARS         PIC S9(11)V99 COMP-3 VALUE ZERO.
           05  WS-REJ-DOLLARS          PIC S9(11)V99 COMP-3 VALUE ZERO.
           05  WS-TAX-TOTAL            PIC S9(9)V99 COMP-3 VALUE ZERO.
           05  WS-MGR-COUNT            PIC 9(05) VALUE ZERO.
       01  WS-EDIT-AMT                 PIC $$$,$$$,$$9.99.
       01  WS-EDIT-CNT                 PIC ZZ,ZZ9.
       01  WS-DETAIL                   PIC X(132).
       01  WS-BLANK                    PIC X(132) VALUE SPACES.
       01  WS-TITLE                    PIC X(132) VALUE
           'DAILY ORDER MANAGEMENT SUMMARY REPORT'.
       01  WS-SEP                      PIC X(132) VALUE ALL '-'.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-ACCUM-APPROVED UNTIL END-APPR
           PERFORM 3000-ACCUM-REJECTED UNTIL END-REJ
           PERFORM 4000-ACCUM-LOWSTOCK UNTIL END-LOW
           PERFORM 5000-WRITE-SUMMARY
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           ACCEPT WS-TODAY FROM DATE YYYYMMDD
           OPEN INPUT APPROVED-FILE
           OPEN INPUT REJECTED-FILE
           OPEN INPUT LOWSTOCK-FILE
           OPEN OUTPUT REPORT-FILE
           WRITE RPT-LINE FROM WS-TITLE
           STRING 'REPORT DATE: ' WS-TODAY
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           WRITE RPT-LINE FROM WS-SEP
           WRITE RPT-LINE FROM WS-BLANK
           MOVE 'N' TO WS-EOF-APPR
           MOVE 'N' TO WS-EOF-REJ
           MOVE 'N' TO WS-EOF-LOW
           PERFORM 2100-READ-APPR
           PERFORM 3100-READ-REJ
           PERFORM 4100-READ-LOW.

       2000-ACCUM-APPROVED.
           ADD 1 TO WS-APPR-COUNT
           ADD ORD-TOTAL TO WS-APPR-DOLLARS
           ADD ORD-TAX-AMOUNT TO WS-TAX-TOTAL
           IF ORD-MGR-APPROVAL = 'Y'
               ADD 1 TO WS-MGR-COUNT
           END-IF
           STRING 'APPR ' ORD-NUMBER ' CUST=' ORD-CUST-ID
               ' ITEM=' ORD-ITEM-CODE
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           PERFORM 2100-READ-APPR.

       2100-READ-APPR.
           READ APPROVED-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-APPR
               NOT AT END
                   CONTINUE
           END-READ.

       3000-ACCUM-REJECTED.
           ADD 1 TO WS-REJ-COUNT
           ADD ORD-TOTAL TO WS-REJ-DOLLARS
           STRING 'REJ  ' ORD-NUMBER ' CUST=' ORD-CUST-ID
               ' REASON=' ORD-REJECT-REASON
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           PERFORM 3100-READ-REJ.

       3100-READ-REJ.
           READ REJECTED-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-REJ
               NOT AT END
                   CONTINUE
           END-READ.

       4000-ACCUM-LOWSTOCK.
           ADD 1 TO WS-LOW-COUNT
           STRING 'LOW  ' LOW-LINE
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           PERFORM 4100-READ-LOW.

       4100-READ-LOW.
           READ LOWSTOCK-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-LOW
               NOT AT END
                   CONTINUE
           END-READ.

      *****************************************************************
      * Summary section: totals, reject count, low-stock alerts,
      * manager-approval flags — primary EOD ops metrics.
      *****************************************************************
       5000-WRITE-SUMMARY.
           WRITE RPT-LINE FROM WS-BLANK
           WRITE RPT-LINE FROM WS-SEP
           MOVE '*** DAILY TOTALS ***' TO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-APPR-COUNT TO WS-EDIT-CNT
           STRING 'APPROVED ORDERS: ' WS-EDIT-CNT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-APPR-DOLLARS TO WS-EDIT-AMT
           STRING 'APPROVED DOLLARS: ' WS-EDIT-AMT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-TAX-TOTAL TO WS-EDIT-AMT
           STRING 'TAX COLLECTED:    ' WS-EDIT-AMT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-REJ-COUNT TO WS-EDIT-CNT
           STRING 'REJECTED ORDERS: ' WS-EDIT-CNT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-REJ-DOLLARS TO WS-EDIT-AMT
           STRING 'REJECTED DOLLARS: ' WS-EDIT-AMT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-MGR-COUNT TO WS-EDIT-CNT
           STRING 'MGR APPROVAL FLAGGED: ' WS-EDIT-CNT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           MOVE WS-LOW-COUNT TO WS-EDIT-CNT
           STRING 'LOW STOCK ALERTS: ' WS-EDIT-CNT
               DELIMITED BY SIZE INTO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL
           WRITE RPT-LINE FROM WS-SEP
           MOVE '*** END OF REPORT ***' TO WS-DETAIL
           WRITE RPT-LINE FROM WS-DETAIL.

       9000-TERMINATE.
           CLOSE APPROVED-FILE
           CLOSE REJECTED-FILE
           CLOSE LOWSTOCK-FILE
           CLOSE REPORT-FILE
           DISPLAY 'RPTGEN COMPLETE - APPR=' WS-APPR-COUNT
               ' REJ=' WS-REJ-COUNT
               ' LOW=' WS-LOW-COUNT
           MOVE ZERO TO RETURN-CODE.
