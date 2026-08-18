      *****************************************************************
      * INVREC.cpy - Inventory Master Record Layout
      * Used by INVUPDT and RPTGEN for stock level maintenance
      *****************************************************************
       01  INVENTORY-RECORD.
           05  INV-ITEM-CODE           PIC X(10).
           05  INV-ITEM-DESC           PIC X(30).
           05  INV-WAREHOUSE           PIC X(04).
           05  INV-QTY-ON-HAND         PIC S9(7) COMP-3.
           05  INV-QTY-ALLOCATED       PIC S9(7) COMP-3.
           05  INV-QTY-ON-ORDER        PIC S9(7) COMP-3.
           05  INV-REORDER-POINT       PIC S9(5) COMP-3.
           05  INV-REORDER-QTY         PIC S9(5) COMP-3.
           05  INV-UNIT-COST           PIC S9(7)V99 COMP-3.
           05  INV-UNIT-PRICE          PIC S9(7)V99 COMP-3.
           05  INV-LAST-RCPT-DATE      PIC X(08).
           05  INV-LAST-ISSUE-DATE     PIC X(08).
           05  INV-LOW-STOCK-FLAG      PIC X(01).
      *        Y=Below reorder point  N=OK
           05  INV-STATUS              PIC X(01).
      *        A=Active  D=Discontinued  H=Hold
           05  INV-FILLER              PIC X(20).
