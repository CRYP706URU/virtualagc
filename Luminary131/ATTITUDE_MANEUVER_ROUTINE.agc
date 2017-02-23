### FILE="Main.annotation"
## Copyright:	Public domain.
## Filename:	ATTITUDE_MANEUVER_ROUTINE.agc
## Purpose:	A section of Luminary 1C, revision 131.
##		It is part of the source code for the Lunar Module's (LM)
##		Apollo Guidance Computer (AGC) for Apollo 13.
##		This file is intended to be a faithful transcription, except
##		that the code format has been changed to conform to the
##		requirements of the yaYUL assembler rather than the 
##		original YUL assembler.
## Reference:	pp. 344-365
## Contact:	Ron Burkey <info@sandroid.org>.
## Website:	www.ibiblio.org/apollo/index.html
## Mod history:	05/10/03 RSB.	Began transcribing.
##		05/14/05 RSB	Corrected website reference above.
##		2010-08-24 JL	Added missing page number comments.
##		2017-01-06 RSB	Page numbers now agree with those on the
##				original harcopy, as opposed to the PDF page
##				numbers in 1701.pdf.
##		2017-02-23 RSB	Proofed comment text using octopus/ProoferComments.

## Page 344
# BLOCK 2 LGC ATTITUDE MANEUVER ROUTINE - KALCMANU
#
# MOD 2		DATE 5/1/67	BY DON KEENE
#
# PROGRAM DESCRIPTION
#
# KALCMANU IS A ROUTINE WHICH GENERATES COMMANDS FOR THE LM DAP TO CHANGE THE ATTITUDE OF THE SPACECRAFT
# DURING FREE FALL.  IT IS DESIGNED TO MANEUVER THE SPACECRAFT FROM ITS INITIAL ORIENTATION TO SOME DESIRED
# ORIENTATION SPECIFIED BY THE PROGRAM WHICH CALLS KALCMANU, AVOIDING GIMBAL LOCK IN THE PROCESS.  IN THE 
# MOD 2 VERSION, THIS DESIRED ATTITUDE IS SPECIFIED BY A SET OF THREE COMMANDED CDU ANGLES STORED AS 2S COMPLEMENT
# SINGLE PRECISION ANGLES IN THE THREE CONSECUTIVE LOCATIONS, CPHI, CTHETA, CPSI, WHERE
#
#	CPHI = COMMANDED OUTER GIMBAL ANGLE
# 	CTHETA = COMMANDED INNER GIMBAL ANGLE
#	CPSI = COMMANDED MIDDLE GIMBAL ANGLE
#
#     WHEN POINTING A SPACECRAFT AXIS (E.I.  X, Y, Z, THE AOT, THRUST AXIS, ETC) THE SUBROUTINE VECPOINT MAY BE
# USED TO GENERATE THIS SET OF DESIRED CDU ANGLES (SEE DESCRIPTION IN R60)    -
#
# WITH THIS INFORMATION KALCMANU DETERMINES THE DIRECTION OF THE SINGLE EQUIVALENT ROTATION (COF ALSO U) AND THE
# MAGNITUDE OF THE ROTATION (AM) TO BRING THE S/C FROM ITS INITIAL ORIENTATION TO ITS FINAL ORIENTATION.
# THIS DIRECTION REMAINS FIXED BOTH IN INERTIAL COORDINATES AND IN COMMANDED S/C AXES THROUGHOUT THE 
#                  -
# MANEUVER.  ONCE COF AND AM HAVE BEEN DETERMINED, KALCMANU THEN EXAMINES THE MANEUVER TO SEE IF IT WILL BRING
# THE S/C THROUGH GIMBAL LOCK.  IF SO, COF AND AM ARE READJUSTED SO THAT THE S/C WILL JUST SKIM THE GIMBAL
# LOCK ZONE AND ALIGN THE X-AXIS.  IN GENERAL A FINAL YAW ABOUT X WILL BE NECESSARY TO COMPLETE THE MANEUVER.
# NEEDLESS TO SAY, NEITHER THE INITIAL NOR THE FINAL ORIENTATION CAN BE IN GIMBAL LOCK.
#
# FOR PROPER ATTITUDE CONTROL THE DIGITAL AUTOPILOT MUST BE GIVEN AN ATTITUDE REFERENCE WHICH IT CAN TRACK.
# KALCMANU DOES THIS BY GENERATING A REFERENCE OF DESIRED GIMBAL ANGLES (CDUXD, CDUYD, CDUZD) WHICH ARE UPDATED
# EVERY ONE SECOND DURING THE MANEUVER.  TO ACHIEVE A SMOOTHER SEQUENCE OF COMMANDS BETWEEN SUCCESSIVE UPDATED,
# THE PROGRAM ALSO GENERATES A SET OF INCREMENTAL CDU ANGLES (DELDCDU) TO BE ADDED TO CDU DESIRED BY THE DIGITAL
# AUTOPILOT.  KALCMANU ALSO CALCULATES THE COMPONENT MANEUVER RATES (OMEGAPD, OMEGAQD, OMEGARD), WHICH CAN
# BE DETERMINED SIMPLY BY MULTIPLYING COF BY SOME SCALAR (ARATE) CORRESPONDING TO THE DESIRED ROTATIONAL RATE.
#
# AUTOMATIC MANEUVERS ARE TIMED WITH THE HELP OF WAITLIST SO THAT AFTER A SPECIFIED INTERVAL THE Y AND Z
# DESIRED RATES ARE SET TO ZERO AND THE DESIRED CDU ANGLES (CDUYD, CDUZD) ARE SET EQUAL TO THE FINAL DESIRED CDU
# ANGLES (CTHETA, CPSI).  IF ANY YAW REMAINS DUE TO GIMBAL LOCK AVOIDANCE, THE FINAL YAW  MANEUVER IS
# CALCULATED AND THE DESIRED YAW RATE SET TO SOME FIXED VALUE (ROLLRATE = + OR - 2 DEGREES PER SEC).
# IN THIS CASE ONLY AN INCREMENTAL CDUX ANGLE (DELFROLL) IS SUPPLIED TO THE DAP.  AT THE END OF THE YAW
# MANEUVER OR IN THE EVENT THAT THERE WAS NO FINAL YAW, CDUXD IS SET EQUAL TO CPHI AND THE X-AXIS DESIRED
# RATE SET TO ZERO.  THUS, UPON COMPLETION OF THE MANEUVER THE S/C WILL FINISH UP IN A LIMIT CYCLE ABOUT THE
# DESIRED FINAL GIMBAL ANGLES.
#
# PROGRAM LOGIC FLOW
#
# KALCMANU IS CALLED AS A HIGH PRIORITY JOB WITH ENTRY POINTS AT KALCMAN3 AND VECPOINT.  IT FIRST PICKS
# UP THE CURRENT CDU ANGLES TO BE USED AS THE BASIS FOR ALL COMPUTATIONS INVOLVING THE INITIAL S/C ORIENTATION.
## Page 345
# IT THEN DETERMINES THE DIRECTION COSINE MATRICES RELATING BOTH THE INITIAL AND FINAL S/C ORIENTATION TO STABLE
#               *   *                                                                               *
# MEMBER AXES (MIS,MFS).  IT ALSO COMPUTES THE MATRIX RELATING FINAL S/C AXES TO INITIAL S/C AXES (MFI).  THE
# ANGLE OF ROTATION (AM) IS THEN EXTRACTED FROM THIS MATRIX, AND TESTS ARE MADE TO DETERMINE IF
#
#	A)	AM LESS THAN .25 DEGREES (MINANG)
#	B)	AM GREATER THAN 170 DEGREES (MAXANG)
#
# IF AM LESS THAN .25 DEGREES, NO COMPLICATED AUTOMATIC MANEUVERING IS NECESSARY.  THEREFORE WE CAN SIMPLY
# SET CDU DESIRED EQUAL TO THE FINAL CDU DESIRED ANGLES AND TERMINATE THE JOB.
#
# IF AM IS GREATER THAN .25 DEGREES BUT LESS THAN 170 DEGREES, THE AXES OF THE SINGLE EQUIVALENT ROTATION
#   -                                                       *
# (COF) IS EXTRACTED FROM THE SKEW SYMMETRIC COMPONENTS OF MFI.                       *     *
# IF AM GREATER THAN 170 DEGREES AN ALTERNATE METHOD EMPLOYING THE SYMMETRIC PART OF MFI (MFISYM) IS USED
#               -
# TO DETERMINE COF.
#
# THE PROGRAM THEN CHECKS TO SEE IF THE MANEUVER AS COMPUTED WILL BRING THE S/C THROUGH GIMBAL LOCK.  IF
# SO, A NEW MANEUVER IS CALCULATED WHICH WILL JUST SKIM THE GIMBAL LOCK ZONE AND ALIGN THE S/C X-AXIS.  THIS
# METHOD ASSURES THAT THE ADDITIONAL MANEUVERING TO AVOID GIMBAL LOCK WILL BE KEPT TO A MINIMUM   SINCE A FINAL
# P AXIS YAW WILL BE NECESSARY, A SWITCH IS RESET (STATE SWITCH 31) TO ALLOW FOR THE COMPUTATION OF THIS FINAL
# YAW.
#
# AS STATED PREVIOUSLY KALCMANU GENERATES A SEQUENCE OF DESIRED GIMBAL ANGLES WHICH ARE UPDATED EVERY 
#                                                                                              -
# SECOND.  THIS IS ACCOMPLISHED BY A SMALL ROTATION OF THE DESIRED S/C FRAME ABOUT THE VECTOR COF.  THE NEW
# DESIRED REFERENCE MATRIX IS THEN,
#	 *		 *	 *
#	MIS	=	MIS	DEL
#	   N+1		   N
#        *
# WHERE DEL IS THE MATRIX CORRESPONDING TO THIS SMALL ROTATION.  THE NEW CDU ANGLES CAN THEN BE EXTRACTED
#       *
# FROM MIS.
#
# AT THE BEGINNING OF THE MANEUVER THE AUTOPILOT DESIRED RATES (OMEGAPD, OMEGAQD, OMEGARD) AND THE 
# MANEUVER TIMINGS ARE ESTABLISHED.  ON THE FIRST PASS AND ON ALL SUBSEQUENT UPDATES THE CDU DESIRED
# ANGLES ARE LOADED WITH THE APPROPRIATE VALUES AND THE INCREMENTAL CDU ANGLES ARE COMPUTED.  THE AGC CLOCKS
# (TIME1 AND TIME2) ARE THAN CHECKED TO SEE IF THE MANEUVER WILL TERMINATE BEFORE THE NEXT UPDATE.  IF
# NOT, KALCMANU CALLS FOR ANOTHER UPDATE (RUN AS A JOB WITH PRIORITY TBD) IN ONE SECOND.  ANY DELAYS IN THIS
# CALLING SEQUENCE ARE AUTOMATICALLY COMPENSATED IN CALLING FOR THE NEXT UPDATE.
#
# IF IT IS FOUND THAT THE MANEUVER IS TO TERMINATE BEFORE THE NEXT UPDATE A ROUTINE IS CALLED (AS A WAIT-
# LIST TASK) TO STOP THE MANEUVER AT THE APPROPRIATE TIME AS EXPLAINED ABOVE.

## Page 346
# CALLING SEQUENCE
#
# IN ORDER TO PERFORM A KALCMANU SUPERVISED MANEUVER, THE COMMANDED GIMBAL ANGLES MUST BE PRECOMPUTED AND
# STORED IN LOCATIONS CPHI, CTHETA, CPSI.  THE USER:S PROGRAM MUST THEN CLEAR STATE SWITCH NO 33 TO ALLOW THE 
# ATTITUDE MANEUVER ROUTINE TO PERFORM ANY FINAL P-AXIS YAW INCURRED BY AVOIDING GIMBAL LOCK.  THE MANEUVER IS
# THEN INITIATED BY ESTABLISHING THE FOLLOWING EXECUTIVE JOB
#		       *
#	CAF	PRIO XX
#		     --
#	INHINT
#	TC	FINDVAC
#	2CADR	KALCMAN3
#	RELINT
#
# THE USER'S PROGRAM MAY EITHER CONTINUE OR WAIT FOR THE TERMINATION OF THE MANEUVER.  IF THE USER WISHES TO
# WAIT, HE MAY PUT HIS JOB TO SLEEP WITH THE FOLLOWING INSTRUCTIONS
#
#	L	TC	BANKCALL
#	L+1	CADR	ATTSTALL
#	L+2	(BAD RETURN)
#	L+3	(GOOD RETURN)
#
# UPON COMPLETION OF THE MANEUVER, THE PROGRAM WILL BE AWAKENED AT L+3 IF THE MANEUVER WAS COMPLETED
# SUCCESSFULLY, OR AT L+2 IF THE MANEUVER WAS ABORTED.  THIS ABORT WOULD OCCUR IF THE INITIAL OR FINAL ATTITUDE
# WAS IN GIMBAL LOCK.
#
# *** NOTA BENE ***  IT IS ASSUMED THAT THE DESIRED MANEUVERING RATE (0.5, 2, 5, 10, DEG/SEC) HAS BEEN SELECTED BY
# KEYBOARD ENTRY PRIOR TO THE EXECUTION OF KALCMANU.
#
# IT IS ALSO ASSUMED THAT THE AUTOPILOT IS IN THE AUTO MODE.  IF THE MODE SWITCH IS CHANGED DURING THE
# MANEUVER, KALCMANU WILL TERMINATE VIA GOODEND WITHIN 1 SECOND SO THAT R60 MAY REQUEST A TRIM OF THE S/C ATTITUDE
# THIS IS THE ONLY MEANS FOR MANUALLY TERMINATING A KALCMANU SUPERVISED MANEUVER.
# SUBROUTINES
#
# KALCMANU USES A NUMBER OF INTERPRETIVE SUBROUTINES WHICH MAY BE OF GENERAL INTEREST.  SINCE THESE ROUTINES
# WERE PROGRAMMED EXCLUSIVELY FOR KALCMANU, THEY ARE NOT, AS YET, GENERALLY AVAILABLE FOR USE BY OTHER PROGRAMS.
#
# MXM3
# ----
#
# THIS SUBROUTINE MULTIPLIES TWO 3X3 MATRICES AND LEAVES THE RESULT IN THE FIRST 18 LOCATIONS OF THE PUSH
# DOWN LIST, I.E.,
#			( M     M     M  )
#			(  0     1     2 )
#	*		(                )		*		*
#	M	=	( M     M     M  )	=	M1	X	M2
#			(  3     4     5 )
#			(                )
#			( M     M     M  )
## Page 347
#			(  6     7     8 )
#                                                                                  *
# INDEX REGISTER X1 MUST BE LOADED WITH THE COMPLEMENT OF THE STARTING ADDRESS FOR M1, AND X2 MUST BE
#                                                        *
# LOADED WITH THE COMPLEMENT OF THE STARTING ADDRESS FOR M2.  THE ROUTINE USES THE FIRST 20 LOCATIONS OF THE PUSH
# DOWN LIST.  THE FIRST ELEMENT OF THE MATRIX APPEARS IN PDO.  PUSH UP FOR M .
#                                                                           8
# TRANSPOS
# --------
#
# THIS ROUTINE TRANSPOSES A 3X3 MATRIX AND LEAVES THE RESULT IN THE PUSH DOWN LIST, I.E.,
# 
#	*		* T
#	M	=	M1
#
# INDEX REGISTER X1 MUST CONTAIN THE COMPLEMENT OF THE STARTING ADDRESS FOR M1.  PUSH UP FOR THE FIRST AND SUB-
#                        *
# SEQUENT COMPONENTS OF M.  THIS SUBROUTINE ALSO USES THE FIRST 20 LOCATIONS OF THE PUSH DOWN LIST.
#
# CDU TO DCM
# ----------
#
# THIS SUBROUTINE CONVERTS THREE CDU ANGLES IN T(MPAC) TO A DIRECTION COSINE MATRIX (SCALED BY 2) RELATING
# THE CORRESPONDING S/C ORIENTATIONS TO THE STABLE MEMBER FRAME.  THE FORMULAS FOR THIS CONVERSION ARE
#
#	M	=	COSY COSZ
#	 0
#
#	M	=	-COSY SINZ COSX + SINY SINX
#	 1
#
#	M	=	COSY SINZ SINX + SINY COSX
#	 2
#
#	M	=	SINZ
#	 3
#
#	M	=	COSZ COSX
#	 4
#
#	M	=	-COSZ SINX
#	 5
#
#	M	=	-SINY COSZ
#	 6
#	
#	M	=	SINY SINZ COSX + COSY SINX
#	 7
## Page 348
#	M	=	-SINY SINZ SINX + COSY COSX
#	 8
#
# WHERE		X	=	OUTER GIMBAL ANGLE
#		Y	=	INNER GIMBAL ANGLE
#		Z	=	MIDDLE GIMBAL ANGLE
#
# THE INTERPRETATION OF THIS MATRIX IS AS FOLLOWS
#
# IF A , A , A  REPRESENT THE COMPONENTS OF A VECTOR IN S/C AXES THEN THE COMPONENTS OF THE SAME VECTOR IN
#     X   Y   Z
# STABLE MEMBER AXES (B , B , B ) ARE
#                      X   Y   Z
#
#	( B  )			( A  )
#	(  X )			(  X )
#	(    )			(    )
#	(    )            *     (    )
#	( B  )	   =	  M	( A  )
#	(  Y )	         	(  Y )
#	(    )			(    )
#	( B  )			( A  )
#	(  Z )			(  Z )
#
# THE SUBROUTINE WILL STORE THIS MATRIX IN SEQUENTIAL LOCATIONS OF ERASABLE MEMORY AS SPECIFIED BY THE CALLING
#                                                                                                             *
# PROGRAM.  TO DO THIS THE CALLING PROGRAM MUST FIRST LOAD X2 WITH THE COMPLEMENT OF THE STARTING ADDRESS FOR M.
#
# INTERNALLY, THE ROUTINE USES THE FIRST 16 LOCATIONS OF THE PUSH DOWN LIST, ALSO STEP REGISTER S1 AND INDEX
# REGISTER X2.
#
# DCM TO CDU
# ----------
#								      *
# THIS ROUTINE EXTRACTS THE CDU ANGLES FROMA DIRECTION COSINE MATRIX (M SCALED BY 2) RELATING S/C AXIS TO
#                                                                                 *
# STABLE MEMBER AXES.  X1 MUST CONTAIN THE COMPLEMENT OF THE STARTING ADDRESS FOR M.  THE SUBROUTINE LEAVES THE
# CORRESPONDING GIMBAL ANGLES IN V(MPAC) AS DOUBLE PRECISION 1:S COMPLEMENT ANGLES ACALED BY 2PI.  THE FORMULAS
# FOR THIS CONVERSION ARE
#
#	Z 	=	ARCSIN (M  )
#			         3
#
#	Y	=	ARCSIN (-M /COSZ)
#			          6
#
# IF M  IS NEGATIVE, Y IS REPLACED BY PI SGN Y - Y
#     0
## Page 349
#	X	=	ARCSIN (-M /COSZ)
#			          5
#
# IF M  IS NEGATIVE X IS REPLACED BY PI SGN X - X
#     4
#
# THIS ROUTINE DOES NOT SET THE PUSH DOWN POINTER, BUT USES THE NEXT 8 LOCATIONS OF THE PUSH DOWN LIST AND
# RETURNS THE POINTER TO ITS ORIGINAL SETTING.  THIS PROCEDURE ALLOWS THE CALLER TO STORE THE MATRIX AT THE TOP OF
# THE PUSH DOWN LIST.
#
# DELCOMP
# -------
#                                                     *
# THIS ROUTINE COMPUTES THE DIRECTION COSINE MATRIX (DEL) RELATING ON
#                                                                          -
# IS ROTATED WITH RESPECT TO THE FIRST BY AN ANGLE, A, ABOUT A UNIT VECTOR, U.  THE FORMULA FOR THIS MATRIX IS
#
#	 *		*	 - -T              *
#	DEL	=	I COSA + U U  (1 - COSA) + V  SINA
#			                            X
#
# WHERE		*		( 1    0    0 )
#		I	=	( 0    1    0 )
#				( 0    0    1 )
#
#				     2                             
#				(  U           U  U          U  U  )
#				(   X           X  Y          X  Z )
#				(                                  )
#		- -T		(                 2                )
#		U U	=	( U  U          U            U  U  )
#				(  Y  X          Y            Y  Z )
#				(                                  )
#				(                               2  )
#				( U  U         U  U           U    )
#				(  Z  X         X  Y           Z   )
#
#
#				(   0		-U		 U  )
#				(		  Z		  Y )
#		*		(				    )
#		V	=	(  U		 0		-U  )
#		 X		(   Z                             X )
#				(				    )
#				( -U		 U		 0  )
#				(   Y 		  X		    )
#
## Page 350
#	-
#	U	=	UNIT ROTATION VECTOR RESOLVED INTO S/C AXES
#	A	=	ROTATION ANGLE
#
#                        *
# THE INTERPRETATION OF DEL IS AS FOLLOWS
#
# IF A , A , A  REPRESENT THE COMPONENT OF A VECTOR INTHE ROTATED FRAME, THEN THE COMPONENTS OF THE SAME
#     X   Y   Z
# VECTOR IN THE ORIGINAL S/C AXES (B , B , B ) ARE
#                                   X   Y   Z
#
#	( B  )			( A  )
#	(  X )			(  X )
#	(    )		  *	(    )
#	( B  )	   =     DEL	( A  )
#	(  Y )	        	(  Y )
#	(    )			(    )
#	( B  )			( A  )
#	(  Z )			(  Z )
#
# THE ROUTINE WILL STORE THIS MATRIX (SCALED UNITY) IN SEQUENTIAL LOCATIONS OF ERASABLE MEMORY BEGINNING WITH
#                                                                                             -
# THE LOCATION CALLED DEL.  IN ORDER TO USE THE ROUTINE, THE CALLING PROGRAM MUST FIRST STORE U (A HALF UNIT
# DOUBLE PRECISION VECTOR) IN THE SET OF ERASABLE LOCATIONS BEGINNING WITH THE ADDRESS CALLED COF.  THE ANGLE, A,
# MUST THEN BE LOADED INTO D(MPAC).
# 
# INTERNALLY, THE PROGRAM ALSO USES THE FIRST 10 LOCATIONS OF THE PUSH DOWN LIST.
#
# READCDUK
# --------
#
# THIS BASIC LANGUAGE SUBROUTINE LOADS T(MPAC) WITH THE THREE CDU ANGLES.
#
# SIGNMPAC
# --------
#
# THIS IS A BASIC LANGUAGE SUBROUTINE WHICH LIMITS THE MAGNITUDE OF D(MPAC) TO + OR - DPOSMAX ON OVERFLOW.
#
# PROGRAM STORAGE ALLOCATION
#
#	1)	FIXED MEMORY		1059 WORDS
#	2)	ERASABLE MEMORY		  98
#	3)	STATE SWITCHES		   3
## Page 351
#	4)	FLAGS			   1
#
# JOB PRIORITIES
#
#	1)	KALCMANU		TBD
#	2)	ONE SECOND UPDATE	TBD
#
# SUMMARY OF STATE SWITCHES AND FLAGWORDS USED BY KALCMANU.
#
#	STATE		FLAGWRD 2	SETTING		MEANING
#	SWITCH NO.	BIT NO.
#
#	  *
#	31		14		0		MANEUVER WENT THROUGH GIMBAL LOCK
#					1		MANEUVER DID NOT GO THROUGH GIMBAL LOCK
#	  *
#	32		13		0		CONTINUE UPDATE PROCESS
#					1		START UPDATE PROCESS
#
#	33		12		0		PERFORM FINAL P-AXIS YAW IF REQUIRED
#					1		IGNORE ANY FINAL P-AXIS YAW
#
#	34		11		0		SIGNAL END OF KALCMANU
#					1		KALCMANU IN PROCESS	USER MUST SET SWITCH BEFORE INITIATING
#
#	* INTERNAL TO KALCMANU
#
# SUGGESTIONS FOR PROGRAM INTEGRATION
#
# THE FOLLOWING VARIABLES SHOULD BE ASSIGNED TO UNSWITCH ERASABLE
#
#	CPHI
#	CTHETA
#	CPSI
#	POINTVSM +5
#	SCAXIS +5
#	DELDCDU
#	DELDCDU1
#	DELDCDU2
#	RATEINDX
#
# THE FOLLOWING SUBROUTINES MAY BE PUT IN A DIFFERENT BANK
#
#	MXM3
## Page 352
#	TRANSPOS
#	SIGNMPAC
#	READCDUK
#	CDUTODCM

## Page 353
		BANK	15
		SETLOC	KALCMON1
		BANK
		
		EBANK=	BCDU
		
# THE THREE DESIRED CDU ANGLES MUST BE STORED AS SINGLE PRECISION TWOS COMPLEMENT ANGLES IN THE THREE SUCCESSIVE
# LOCATIONS, CPHI, CTHETA, CPSI.

		COUNT*	$$/KALC
KALCMAN3	TC	INTPRET		# PICK UP THE CURRENT CDU ANGLES AND
		RTB			#	COMPUTE THE MATRIX FROM INITIAL S/C
			READCDUK	#	AXES TO FINAL S/C AXES
		STORE	BCDU		# STORE INITIAL S/C ANGLES
		SLOAD	ABS		# CHECK THE MAGNITUDE OF THE DESIRED
			CPSI		# MIDDLE GIMBAL ANGLE
		DSU	BPL
			LOCKANGL	# IF GREATER THAN 70 DEG ABORT MANEUVER
			TOOBADF
		AXC,2	TLOAD
			MIS
			BCDU
		CALL			# COMPUTE THE TRANSFORMATION FROM INITIAL
			CDUTODCM	# S/C AXES TO STABLE MEMBER AXES
		AXC,2	TLOAD
			MFS		# PREPARE TO CALCULATE ARRAY MFS
			CPHI
		CALL
			CDUTODCM
SECAD		AXC,1	CALL		# MIS AND MFS ARRAYS CALCULATED		$2
			MIS
			TRANSPOS
		VLOAD	STADR
		STOVL	TMIS +12D
		STADR
		STOVL	TMIS +6
		STADR
		STORE	TMIS		# TMIS = TRANSPOSE(MIS) SCALED BY 2
		AXC,1	AXC,2
			TMIS
			MFS
		CALL
			MXM3
		VLOAD	STADR
		STOVL	MFI +12D
		STADR
		STOVL	MFI +6
		STADR
		STORE	MFI		# MFI = TMIS MFS (SCALED BY 4)
		SETPD	CALL		# TRANSPOSE MFI IN PD LIST
## Page 354
			18D
			TRNSPSPD
		VLOAD	STADR
		STOVL	TMFI +12D
		STADR
		STOVL	TMFI +6
		STADR
		STORE	TMFI		# TMFI = TRANSPOSE (MFI) SCALED BY 4
		
# CALCULATE COFSKEW AND MFISYM

		DLOAD	DSU
			TMFI +2
			MFI +2
		PDDL	DSU		# CALCULATE COF SCALED BY 2/SIN(AM)
			MFI +4
			TMFI +4
		PDDL	DSU
			TMFI +10D
			MFI +10D
		VDEF
		STORE	COFSKEW		# EQUALS MFISKEW
		
# CALCULATE AM AND PROCEED ACCORDING TO ITS MAGNITUDE

		DLOAD	DAD
			MFI
			MFI +16D
		DSU	DAD
			DP1/4TH
			MFI +8D
		STORE	CAM		# CAM = (MFI0+MFI4+MFI8-1)/2 HALF SCALE
		ARCCOS
		STORE	AM		# AM=ARCCOS(CAM)	(AM SCALED BY 2)
		DSU	BPL
			MINANG
			CHECKMAX
		TLOAD			# MANEUVER LESS THAN .25 DEGREES
			CPHI		# GO DIRECTLY INTO ATTITUDE HOLD
		STCALL	CDUXD		# ABOUT COMMANDED ANGLES
			TOOBADI		# STOP RATE AND EXIT
			
CHECKMAX	DLOAD	DSU
			AM
			MAXANG
		BPL	VLOAD
			ALTCALC		# UNIT
			COFSKEW		# COFSKEW
		UNIT
		STORE	COF		# COF IS THE MANEUVER AXIS
## Page 355
		GOTO			# SEE IF MANEUVER GOES THRU GIMBAL LOCK
			LOCSKIRT
ALTCALC		VLOAD	VAD		# IF AM GREATER THAN 170 DEGREES
			MFI
			TMFI
		VSR1
		STOVL	MFISYM
			MFI +6
		VAD	VSR1
			TMFI +6
		STOVL	MFISYM +6
			MFI +12D
		VAD	VSR1
			TMFI +12D
		STORE	MFISYM +12D	# MFISYM=(MFI+TMFI)/2	SCALED BY 4
		
# CALCULATE COF

		DLOAD	SR1
			CAM
		PDDL	DSU		# PDO CAM				$4
			DPHALF
			CAM
		BOVB	PDDL		# PD2 1 - CAM				$2
			SIGNMPAC
			MFISYM +16D
		DSU	DDV
			0
			2
		SQRT	PDDL		# COFZ = SQRT(MFISYM8-CAM)/1-CAM)
			MFISYM +8D	#				$ ROOT 2
		DSU	DDV
			0
			2
		SQRT	PDDL		# COFY = SQRT(MFISYM4-CAM)/(1-CAM)	$ROOT2
			MFISYM
		DSU	DDV
			0
			2
		SQRT	VDEF		# COFX = SQRT(MFISYM-CAM)/(1-CAM)	$ROOT 2
		UNIT
		STORE	COF
		
# DETERMINE LARGEST COF AND ADJUST ACCORDINGLY

COFMAXGO	DLOAD	DSU
			COF
			COF +2
		BMN	DLOAD		# COFY G COFX
## Page 356
			COMP12
			COF
		DSU	BMN
			COF +4
			METHOD3		# COFZ G COFX OR COFY
		GOTO
			METHOD1		# COFX G COFY OR COFZ
COMP12		DLOAD	DSU
			COF +2
			COF +4
		BMN	
			METHOD3		# COFZ G COFY OR COFX
			
METHOD2		DLOAD	BPL		# COFY MAX
			COFSKEW +2	# UY
			U2POS
		VLOAD	VCOMP
			COF
		STORE	COF
U2POS		DLOAD	BPL
			MFISYM +2	# UX UY
			OKU21
		DLOAD	DCOMP		# SIGN OF UX OPPOSITE TO UY
			COF
		STORE	COF
OKU21		DLOAD	BPL
			MFISYM +10D	# UY UZ
			LOCSKIRT
		DLOAD	DCOMP		# SIGN OF UZ OPPOSITE TO UY
			COF +4
		STORE	COF +4
		GOTO
			LOCSKIRT
METHOD1		DLOAD	BPL		# COFX MAX
			COFSKEW		# UX
			U1POS
		VLOAD	VCOMP
			COF
		STORE	COF
U1POS		DLOAD	BPL
			MFISYM +2	# UX UY
			OKU12
		DLOAD	DCOMP
			COF +2		# SIGN OF UY OPPOSITE TO UX
		STORE	COF +2
OKU12		DLOAD	BPL
			MFISYM +4	# UX UZ
			LOCSKIRT
		DLOAD	DCOMP		# SIGN OF UZ OPPOSITE TO UY
			COF +4
## Page 357
		STORE	COF +4
		GOTO
			LOCSKIRT
METHOD3		DLOAD	BPL		# COFZ MAX
			COFSKEW +4	# UZ
			U3POS
		VLOAD	VCOMP
			COF
		STORE	COF
U3POS		DLOAD	BPL
			MFISYM +4	# UX UZ
			OKU31
		DLOAD	DCOMP
			COF		# SIGN OF UX OPPOSITE TO UZ
		STORE	COF
OKU31		DLOAD	BPL
			MFISYM +10D	# UY UZ
			LOCSKIRT
		DLOAD	DCOMP
			COF +2		# SIGN OF UY OPPOSITE TO UZ
		STORE	COF +2
		GOTO
			LOCSKIRT
## Page 358
# MATRIX OPERATIONS

		BANK	13
		SETLOC	KALCMON2
		BANK
		
		EBANK=	BCDU
		
MXM3		SETPD	VLOAD*		# MXM3 MULTIPLIES 2 3X3 MATRICES
			0		# AND LEAVES RESULT IN PD LIST
			0,1		# AND MPAC
		VXM*	PDVL*
			0,2
			6,1
		VXM*	PDVL*
			0,2
			12D,1
		VXM*	PUSH
			0,2
		RVQ
		
# RETURN WITH MIXM2 IN PD LIST

TRANSPOS	SETPD	VLOAD*		# TRANSPOS TRANSPOSES A 3X3 MATRIX
			0		# 	AND LEAVES RESULT IN PD LIST
			0,1		# MATRIX ADDRESS IN XR1
		PDVL*	PDVL*
			6,1
			12D,1
		PUSH			# MATRIX IN PD
TRNSPSPD	EXIT			# ENTER WITH MATRIX AT 0 IN PD LIST
		INDEX	FIXLOC
		DXCH	12
		INDEX	FIXLOC
		DXCH	16
		INDEX	FIXLOC
		DXCH	12
		INDEX	FIXLOC
		DXCH	14
		INDEX	FIXLOC
		DXCH	4
		INDEX	FIXLOC
		DXCH	14
		INDEX	FIXLOC
		DXCH	2
		INDEX	FIXLOC
		DXCH	6
		INDEX	FIXLOC
		DXCH	2
## Page 359
		TC	INTPRET
		RVQ
		
		BANK	15
		SETLOC	KALCMON1
		BANK
		
		EBANK=	BCDU
		
MINANG		2DEC	0.00069375
MAXANG		2DEC	0.472222222

# GIMBAL LOCK CONSTANTS

# D = MGA CORRESPONDING TO GIMBAL LOCK = 60 DEGREES
#	NGL = BUFFER ANGLE (TO AVOID DIVISIONS BY ZERO) = 2 DEGREES

SD		2DEC	.433015		# = SIN(D)				$2
K3S1		2DEC	.86603		# = SIN(D)				$1
K4		2DEC	-.25		# = -COS(D)				$2
K4SQ		2DEC	.125		# = COS(D)COS(D)			$2
SNGLCD		2DEC	.008725		# = SIN(NGL)COS(D)			$2
CNGL		2DEC	.499695		# COS(NGL)				$2
LOCKANGL	DEC	.388889		# = 70 DEGREES

# INTERPRETIVE SUBROUTINE TO READ THE CDU ANGLES

READCDUK	CA	CDUZ		# LOAD T(MPAC) WITH CDU ANGLES
		TS	MPAC +2
		EXTEND
		DCA	CDUX		# AND CHANGE MODE TO TRIPLE PRECISION
		TCF	TLOAD +6
		
CDUTODCM	AXT,1	SSP
		OCT	3
			S1
		OCT	1		# SET XR1, S1, AND PD FOR LOOP
		STORE	7
		SETPD
			0
LOOPSIN		SLOAD*	RTB
			10D,1
			CDULOGIC
## Page 360
		STORE	10D		# LOAD PD WITH 	0 SIN(PHI)
		SIN	PDDL		#		2 COS(PHI)
			10D		#		4 SIN(THETA)
		COS	PUSH		#		6 COS(THETA)
		TIX,1	DLOAD		#		8 SIN(PSI)
			LOOPSIN		#		10 COS(PSI)
			6
		DMP	SL1
			10D
		STORE	0,2		# C0 = COS(THETA)COS(PSI)
		DLOAD	DMP
			4
			0
		PDDL	DMP		# (PD6 SIN(THETA)SIN(PHI))
			6
			8D
		DMP	SL1
			2
		BDSU	SL1
			12D
		STORE	2,2		# C1=-COS(THETA)SIN(PSI)COS(PHI)
		DLOAD	DMP
			2
			4
		PDDL	DMP		# (PD7 COS(PHI)SIN(THETA)) SCALED 4
			6
			8D
		DMP	SL1
			0
		DAD	SL1
			14D
		STORE	4,2		# C2=COS(THETA)SIN(PSI)SIN(PHI)
		DLOAD
			8D
		STORE	6,2		# C3=SIN(PSI)
		DLOAD
			10D
		DMP	SL1
			2
		STORE	8D,2		# C4=COS(PSI)COS(PHI)
		DLOAD	DMP
			10D
			0
		DCOMP	SL1
		STORE	10D,2		# C5=-COS(PSI)SIN(PHI)
		DLOAD	DMP
			4
			10D
		DCOMP	SL1
		STORE	12D,2		# C6=-SIN(THETA)COS(PSI)
## Page 361
		DLOAD
		DMP	SL1		# (PUSH UP 7)
			8D
		PDDL	DMP		# (PD7 COS(PHI)SIN(THETA)SIN(PSI)) SCALE 4
			6
			0
		DAD	SL1		# (PUSH UP 7)
		STADR			# C7=COS(PHI)SIN(THETA)SIN(PSI)
		STORE	14D,2		# 	+COS(THETA)SIN(PHI)
		DLOAD
		DMP	SL1		# (PUSH UP 6)
			8D
		PDDL	DMP		# (PD6 SIN(THETA)SIN(PHI)SIN(PSI)) SCALE 4
			6
			2
		DSU	SL1		# (PUSH UP 6)
		STADR
		STORE	16D,2		# C8=-SIN(THETA)SIN(PHI)SIN(PSI)
		RVQ			# +COS(THETA)COS(PHI)
		
# CALCULATION OF THE MATRIX DEL......
#
#	 *         *           --T           *
#	DEL = (IDMATRIX)COS(A)+UU (1-COS(A))+UX SIN(A)		SCALED 1
#	      -
#	WHERE U IS A UNIT VECTOR (DP SCALED 2) ALONG THE AXIS OF ROTATION.
#	A IS THE ANGLE OF ROTATION (DP SCALED 2)
#	                                   -
#	UPON ENTRY THE STARTING ADDRESS OF U IS COF, AND A IS IN MPAC

DELCOMP		SETPD	PUSH		# MPAC CONTAINS THE ANGLE A
 			0
		SIN	PDDL		# PD0 = SIN(A)
		COS	PUSH		# PD2 = COS(A)
		SR2	PDDL		# PD2 = COS(A)					$8
		BDSU	BOVB
			DPHALF
			SIGNMPAC
		PDDL			# PDA = 1-COS(A)
		
# COMPUTE THE DIAGONAL COMPONENTS OF DEL

			COF
		DSQ	DMP
			4
		DAD	SL3
			2
		BOVB
			SIGNMPAC
## Page 362
		STODL	KEL		# UX UX(1-COS(A)) +COS(A)		$1
			COF +2
		DSQ	DMP
			4
		DAD	SL3
			2
		BOVB
			SIGNMPAC
		STODL	KEL +8D		# UY UY(1-COS(A)) +COS(A)		$1
			COF +4
		DSQ	DMP
			4
		DAD	SL3
			2
		BOVB	
			SIGNMPAC
		STORE	KEL +16D	# UZ UZ(1-COS(A)) +COS(A)		$1
		
# COMPUTE TEH OFF DIAGONAL TERMS OF DEL

		DLOAD	DMP
			COF
			COF +2
		DMP	SL1
			4
		PDDL	DMP		# D6	 UX UY (1-COS A)		$4
			COF +4
			0
		PUSH	DAD		# D8 	UZ SIN A			$4
			6
		SL2	BOVB
			SIGNMPAC
		STODL	KEL +6
		BDSU	SL2
		BOVB
			SIGNMPAC
		STODL	KEL +2
			COF
		DMP	DMP
			COF +4
			4
		SL1	PDDL		# D6 	UX UZ (1-COS A)			$4
			COF +2
		DMP	PUSH		# D8	UY SIN(A)
			0
		DAD	SL2
			6
		BOVB
			SIGNMPAC
		STODL	KEL +4		# UX UZ (1-COS(A))+UY SIN(A)
## Page 363
		BDSU	SL2
		BOVB
			SIGNMPAC
		STODL	KEL +12D	# UX UZ (1-COS(A))-UY SIN(A)
			COF +2
		DMP	DMP
			COF +4
			4
		SL1	PDDL		# D6	UY UZ (1-COS(A))			$4
			COF
		DMP	PUSH		# D8	UX SIN(A)
			0
		DAD	SL2
			6
		BOVB
			SIGNMPAC
		STODL	KEL +14D	# UY UZ(1-COS(A)) +UX SIN(A)
		BDSU	SL2
		BOVB
			SIGNMPAC
		STORE	KEL +10D	# UY UZ (1-COS(A)) -UX SIN(A)
		RVQ
		
# DIRECTION COSINE MATRIX TO CDU ANGLE ROUTINE
#
# X1 CONTAINS THE COMPLEMENT OF THE STARTING ADDRESS FOR MATRIX (SCALED 2)
# LEAVES CDU ANGLES SCALED 2PI IN V(MPAC)
# COS(MGA) WILL BE LEFT IN S1 (SCALED 1)
# THE DIRECTION COSINE MATRIX RELATING S/C AXES TO STABLE MEMBER AXES CAN BE WRITTEN AS***
#
#	C =COS(THETA)COS(PSI)
#	 0
#
#	C =-COS(THETA)SIN(PSI)COS(PHI)+SI (THETA)SIN(PHI)
#	 1
#
#	C =COS(THETA)SIN(PSI)SIN(PHI) + S N(THETA)COS(PHI)
#	 2
#
#	C =SIN(PSI)
#	 3
#
#	C =COS(PSI)COS(PHI)
#	 4
#
#	C =-COS(PSI)SIN(PHI)
#	 5
#
#	C =-SIN(THETA)COS(PSI)
#	 6
#
#	C =SIN(THETA)SIN(PSI)COS(PHI)+COS THETA)SIN(PHI)
#	 7
#
#	C =-SIN(THETA)SIN(PSI)SIN(PHI)+CO (THETA)COS(PHI)
#	 8
## Page 364
#
# WHERE	PHI = OGA
#	THETA = IGA
#	PSI = MGA

DCMTOCDU	DLOAD*	ARCSIN
			6,1
		PUSH	COS		# PD +0 	PSI
		SL1	BOVB
			SIGNMPAC
		STORE	S1
		DLOAD*	DCOMP
			12D,1
		DDV	ARCSIN
			S1
		PDDL*	BPL		# PD +2		THETA
			0,1		# MUST CHECK THE SIGN OF COS(THETA)
			OKTHETA		# TO DETERMINE THE PROPER QUADRANT
		DLOAD	DCOMP
		BPL	DAD
			SUHALFA
			DPHALF
		GOTO
			CALCPHI
SUHALFA		DSU
			DPHALF
CALCPHI		PUSH
OKTHETA		DLOAD*	DCOMP
			10D,1
		DDV	ARCSIN
			S1
		PDDL*	BPL		# PUSH DOWN PHI
			8D,1
			OKPHI
		DLOAD	DCOMP		# PUSH UP PHI
		BPL	DAD
			SUHALFAP
			DPHALF
		GOTO
			VECOFANG
SUHALFAP	DSU	GOTO
			DPHALF
			VECOFANG
OKPHI		DLOAD			# PUSH UP PHI
VECOFANG	VDEF	RVQ
## Page 365
# ROUTINES FOR TERMINATING THE AUTOMATIC MANEUVER AND RETURNING TO USER

TOOBADF		EXIT
		TC	ALARM
		OCT	00401
		
		TCF	NOGO		# DO NOT ZERO ATTITUDE ERRORS
		
		TC	BANKCALL
		CADR	ZATTEROR	# ZERO ATTITUDE ERRORS
		
NOGO		TC	BANKCALL
		CADR	STOPRATE	# STOP RATES
		
		CAF	TWO
		INHINT			# ALL RETURNS ARE NOW MADE VIA GOODEND
		TC	WAITLIST
		EBANK=	BCDU
		2CADR	GOODMANU
		
		TCF	ENDOFJOB
		
TOOBADI		EXIT
		TCF	NOGO
		

