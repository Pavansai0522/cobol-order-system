      *****************************************************************
      * ORDREC.cpy - Order Transaction / Order Detail Record Layout
      * Used by ORDENTRY, ORDPROC, INVUPDT, RPTGEN
      *****************************************************************
       01  ORDER-RECORD.
           05  ORD-NUMBER              PIC X(10).
           05  ORD-CUST-ID             PIC X(10).
           05  ORD-DATE                PIC X(08).
      *        Format: YYYYMMDD
           05  ORD-ITEM-CODE           PIC X(10).
           05  ORD-ITEM-DESC           PIC X(30).
           05  ORD-QTY                 PIC S9(5) COMP-3.
           05  ORD-UNIT-PRICE          PIC S9(7)V99 COMP-3.
           05  ORD-SUBTOTAL            PIC S9(9)V99 COMP-3.
           05  ORD-TAX-AMOUNT          PIC S9(7)V99 COMP-3.
           05  ORD-TOTAL               PIC S9(9)V99 COMP-3.
           05  ORD-SHIP-STATE          PIC X(02).
           05  ORD-STATUS              PIC X(01).
      *        P=Pending  A=Approved  R=Rejected  C=Complete
           05  ORD-REJECT-REASON       PIC X(40).
           05  ORD-MGR-APPROVAL        PIC X(01).
      *        Y=Required/Approved  N=Not required  blank=pending
           05  ORD-WAREHOUSE           PIC X(04).
           05  ORD-FILLER              PIC X(15).
