      *****************************************************************
      * CUSTREC.cpy - Customer Master Record Layout
      * Fixed-width VSAM-style customer record for CUSTMAST / ORDPROC
      *****************************************************************
       01  CUSTOMER-RECORD.
           05  CUST-ID                 PIC X(10).
           05  CUST-NAME               PIC X(40).
           05  CUST-ADDR-LINE1         PIC X(40).
           05  CUST-ADDR-LINE2         PIC X(40).
           05  CUST-CITY               PIC X(25).
           05  CUST-STATE              PIC X(02).
           05  CUST-ZIP                PIC X(10).
           05  CUST-PHONE              PIC X(15).
           05  CUST-STATUS             PIC X(01).
      *        A=Active  I=Inactive  H=Credit Hold
           05  CUST-CREDIT-LIMIT       PIC S9(9)V99 COMP-3.
           05  CUST-CURRENT-BALANCE    PIC S9(9)V99 COMP-3.
           05  CUST-YTD-ORDERS         PIC S9(7)V99 COMP-3.
           05  CUST-LAST-ORDER-DATE    PIC X(08).
      *        Format: YYYYMMDD
           05  CUST-ACCT-OPEN-DATE     PIC X(08).
           05  CUST-SALES-REP          PIC X(08).
           05  CUST-FILLER             PIC X(20).
