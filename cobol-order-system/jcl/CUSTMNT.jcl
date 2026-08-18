//CUSTMNT  JOB (ACCT),'CUSTOMER MAINT',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID,REGION=0M
//*=================================================================
//* CUSTMNT - Customer Master Maintenance Job
//* Runs CUSTMAST against customer transaction input
//*=================================================================
//*
//********************************************************************
//* STEP 1 - CUSTOMER MASTER MAINTENANCE (ADD/UPDATE/INQUIRE)
//********************************************************************
//CUSTMAST EXEC PGM=CUSTMAST
//STEPLIB  DD  DSN=PRODLIB.LOADLIB,DISP=SHR
//CUSTMAST DD  DSN=CUSTOMER.MASTER.VSAM,DISP=SHR
//CUSTTRAN DD  DSN=CUSTOMER.MAINT.TRAN,
//             DISP=SHR
//CUSTRPT  DD  DSN=REPORTS.CUSTOMER.MAINT,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(5,2),RLSE),
//             DCB=(RECFM=FB,LRECL=132,BLKSIZE=0)
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
//********************************************************************
//* Optional: run order entry after successful customer maint
//* Only if CUSTMAST return code is less than 8
//********************************************************************
//ORDENTRY EXEC PGM=ORDENTRY,COND=(8,LE,CUSTMAST)
//STEPLIB  DD  DSN=PRODLIB.LOADLIB,DISP=SHR
//ORDIN    DD  DSN=ORDERS.ENTRY.INPUT,DISP=SHR
//ORDOUT   DD  DSN=ORDERS.PENDING.FILE,
//             DISP=(MOD,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(5,2),RLSE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=0)
//CUSTMAST DD  DSN=CUSTOMER.MASTER.VSAM,DISP=SHR
//INVMAST  DD  DSN=INVENTORY.MASTER.VSAM,DISP=SHR
//ORDERR   DD  DSN=ORDERS.ENTRY.ERRORS,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(2,1),RLSE),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=0)
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
