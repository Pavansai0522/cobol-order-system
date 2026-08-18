//ORDDAILY JOB (ACCT),'DAILY ORDER BATCH',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID,REGION=0M
//*=================================================================
//* ORDDAILY - Daily Order Processing Batch Stream
//* Sequence: ORDPROC -> INVUPDT -> RPTGEN
//* COND codes skip downstream steps on severe prior failures
//*=================================================================
//*
//********************************************************************
//* STEP 1 - ORDER PROCESSING / VALIDATION
//********************************************************************
//ORDPROC  EXEC PGM=ORDPROC,COND=(0,LT)
//STEPLIB  DD  DSN=PRODLIB.LOADLIB,DISP=SHR
//ORDPEND  DD  DSN=ORDERS.PENDING.FILE,DISP=SHR
//CUSTMAST DD  DSN=CUSTOMER.MASTER.VSAM,DISP=SHR
//ORDAPPR  DD  DSN=ORDERS.APPROVED.DAILY,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(5,2),RLSE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=0)
//ORDREJ   DD  DSN=ORDERS.REJECTED.DAILY,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(2,1),RLSE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=0)
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
//********************************************************************
//* STEP 2 - INVENTORY UPDATE (skip if ORDPROC RC >= 8)
//********************************************************************
//INVUPDT  EXEC PGM=INVUPDT,COND=(8,LE,ORDPROC)
//STEPLIB  DD  DSN=PRODLIB.LOADLIB,DISP=SHR
//ORDAPPR  DD  DSN=ORDERS.APPROVED.DAILY,DISP=SHR
//INVMAST  DD  DSN=INVENTORY.MASTER.VSAM,DISP=SHR
//LOWSTOCK DD  DSN=INVENTORY.LOWSTOCK.DAILY,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(5,2),RLSE),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=0)
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
//********************************************************************
//* STEP 3 - END-OF-DAY REPORT (skip if INVUPDT RC >= 8)
//********************************************************************
//RPTGEN   EXEC PGM=RPTGEN,COND=((8,LE,ORDPROC),(8,LE,INVUPDT))
//STEPLIB  DD  DSN=PRODLIB.LOADLIB,DISP=SHR
//ORDAPPR  DD  DSN=ORDERS.APPROVED.DAILY,DISP=SHR
//ORDREJ   DD  DSN=ORDERS.REJECTED.DAILY,DISP=SHR
//LOWSTOCK DD  DSN=INVENTORY.LOWSTOCK.DAILY,DISP=SHR
//DAYRPT   DD  DSN=REPORTS.DAILY.SUMMARY,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(10,5),RLSE),
//             DCB=(RECFM=FB,LRECL=132,BLKSIZE=0)
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
//********************************************************************
//* STEP 4 - HOUSEKEEPING: DELETE PENDING AFTER SUCCESSFUL RUN
//********************************************************************
//CLEANUP  EXEC PGM=IEFBR14,COND=((0,LT,ORDPROC),(0,LT,INVUPDT),(0,LT,RPTGEN))
//ORDPEND  DD  DSN=ORDERS.PENDING.FILE,DISP=(OLD,DELETE,KEEP)
//*
