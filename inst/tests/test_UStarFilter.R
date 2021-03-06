#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++ Unit tests for fConvertTimeToPosix functions +++
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Author: TW
#require(testthat)
context("UStarFilter")
require(plyr)
# Furher context: fCheckColNames, fCheckColNumeric, fCheckOutsideRange

if( !exists(".binUstar") ) .binUstar <- REddyProc:::.binUstar

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Dir.s <- paste(system.file(package='REddyProc'), 'examples', sep='/')
EddyData.F <- fLoadTXTIntoDataframe('Example_DETha98.txt', Dir.s)
EddyDataWithPosix.F <- ds <- fConvertTimeToPosix(EddyData.F, 'YDH', Year.s='Year', Day.s='DoY', Hour.s='Hour')
dss <- subset(EddyDataWithPosix.F, DoY >= 150 & DoY <= 250)


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


test_that(".binUstar classes are correct",{
	res <- .binUstar(dss$NEE, dss$Ustar)$binAverages
	UstarClasses <- usControlUstarSubsetting()$UstarClasses
	Ust_bin_size <- round(nrow(dss)/UstarClasses)
	expect_true( all(abs(res$nRec[-nrow(res)] - Ust_bin_size) < 60) )
	# create df of NEE and UStar ordered by Ustar
	ds.f <- data.frame(NEE=dss$NEE,Ustar=dss$Ustar)
	ds.f <- arrange(ds.f,ds.f[,2])
	# create bin id column 
	#ds.f$bin <- UstarClasses # due to rounding, the last classes may be left and neet to get the last class
	#ds.f$bin[1:(UstarClasses*Ust_bin_size)]	 <-	 rep(1:UstarClasses, each=Ust_bin_size)
	ds.f$bin <- rep(1:nrow(res), times=res$nRec)		
	# do the averaging
	tmp1 <- ddply( ds.f, .(bin), function(dsBin){ c(Ust_avg=mean(dsBin[,2], na.rm=TRUE),NEE_avg=mean(dsBin[,1], na.rm=TRUE))})
	expect_that( res[,1:2], equals(tmp1[,-1]))
})

test_that(".binUstar example file",{
			pkgDir <- system.file(package='REddyProc')
			if( nzchar(pkgDir) ){
				Dir.s <- paste(pkgDir, 'examples', sep='/')
				EddyData.F <- ds <- fLoadTXTIntoDataframe('Example_DETha98.txt', Dir.s)
				EddyDataWithPosix.F <- ds <- fConvertTimeToPosix(EddyData.F, 'YDH', Year.s='Year', Day.s='DoY', Hour.s='Hour')
				dss <- subset(EddyDataWithPosix.F, DoY >= 150 & DoY <= 250 & Rg<10)
				(res <- .binUstar(dss$NEE, dss$Ustar)$binAverages)
				expect_true( nrow(res) >= 18)
				#(resFW1 <- usEstUstarThresholdSingleFw1Binned(res))
				#(resFW2 <- usEstUstarThresholdSingleFw2Binned(res))
			}
		})



test_that("usEstUstarThresholdSingleFw2Binned",{
			# regression test
			Ust_bins.f <- structure(list(Ust_avg = c(0.276666666666667, 0.326666666666667, 
									0.341111111111111, 0.363333333333333, 0.384444444444444, 0.401111111111111, 
									0.417777777777778, 0.434444444444444, 0.462222222222222, 0.495555555555556, 
									0.521111111111111, 0.553333333333333, 0.587777777777778, 0.602222222222222, 
									0.624444444444444, 0.654444444444444, 0.693333333333333, 0.77, 
									0.936666666666667, 2.11), NEE_avg = c(1.105, 1.26888888888889, 
									1.22444444444444, 0.908888888888889, 0.888888888888889, 1.13333333333333, 
									1.85888888888889, 1.46777777777778, 2.30222222222222, 1.95, 0.948888888888889, 
									1.09888888888889, 2.36666666666667, 0.985555555555556, 1.30777777777778, 
									1.63555555555556, 1.75777777777778, 1.84222222222222, 1.59, -0.316666666666667
							)), .Names = c("Ust_avg", "NEE_avg"), row.names = c(NA, -20L), class = "data.frame")
			ctrlUstarEst.l <- list(ustPlateauFwd = 10, ustPlateauBack = 6, plateauCrit = 0.95, 
							corrCheck = 0.5)
					#?usEstUstarThresholdSingleFw2Binned
			#trace(usEstUstarThresholdSingleFw2Binned, recover)	# untrace(usEstUstarThresholdSingleFw2Binned)
			UstarEst <- usEstUstarThresholdSingleFw2Binned( Ust_bins.f, ctrlUstarEst.l=ctrlUstarEst.l )
			#plot( NEE_avg ~ Ust_avg , Ust_bins.f);	abline(v=UstarEst)	
			expect_equal( UstarEst, 0.46, tolerance=0.01 )
		})


test_that("sEstUstarThreshold: standard case",{
			EddyProc.C <- sEddyProc$new('DE-Tha', EddyDataWithPosix.F, c('NEE','Rg','Tair','VPD','Ustar'))
			(res <- EddyProc.C$sEstUstarThreshold())
			expect_equal( res$uStarTh$uStar[1], 0.42, tolerance = 0.01, scale = 1 )	# regresssion test: 0.42 by former run
			expect_equal( dim(res$tempInSeason)
				, c( usControlUstarSubsetting()$taClasses,length(unique(usCreateSeasonFactorMonth(EddyProc.C$sDATA$sDateTime))) ))
		})


test_that("sEstUstarThreshold: changing to FW1",{
			EddyProc.C <- sEddyProc$new('DE-Tha', EddyDataWithPosix.F, c('NEE','Rg','Tair','VPD','Ustar'))
			(res <- EddyProc.C$sEstUstarThreshold(fEstimateUStarBinned=usEstUstarThresholdSingleFw1Binned))
			expect_equal( res$uStarTh$uStar[1], 0.34, tolerance = 0.01, scale = 1 )	# regresssion test: 0.42 by former run
			expect_equal( dim(res$tempInSeason)
					, c( usControlUstarSubsetting()$taClasses,length(unique(usCreateSeasonFactorMonth(EddyProc.C$sDATA$sDateTime))) ))
		})

test_that("sEstUstarThreshold: different seasons",{
			EddySetups.C <- sEddyProc$new('DE-Tha', EddyDataWithPosix.F, c('NEE','Rg','Tair','VPD','Ustar'))
			seasonFactor.v <- usCreateSeasonFactorYdayYear( EddySetups.C$sDATA$sDateTime, starts=data.frame(
							startyday=c(30,300,45,280),startyear=c(1998,1998,1999,1999) ))
			expect_warning(	# on too few records
				resUStar <- EddySetups.C$sEstUstarThreshold(seasonFactor.v=seasonFactor.v )
			)
			expect_equal( levels(seasonFactor.v), levels(EddySetups.C$sDATA$season))
		})

test_that("sEstUstarThreshold: using ChangePointDetection",{
			EddySetups.C <- sEddyProc$new('DE-Tha', EddyDataWithPosix.F, c('NEE','Rg','Tair','VPD','Ustar'))
			(resUStar <- EddySetups.C$sEstUstarThreshold(
								#ctrlUstarEst.l=usControlUstarEst(isUsingCPT=TRUE)
								ctrlUstarEst.l=usControlUstarEst(isUsingCPTSeveralT =TRUE)
			))$uStarTh
			# CPT does no binning uStar
			expect_equal( c(0L), as.vector(na.omit(unique(EddySetups.C$sDATA$uStarBin))))
		})

test_that("sEstUstarThreshold: multi-year and One-big-season",{
			EddyData.F99 <- EddyData.F		
			EddyData.F99$Year <- EddyData.F$Year +1
			EddyDataWithPosix.F99 <- fConvertTimeToPosix(EddyData.F99, 'YDH', Year.s='Year', Day.s='DoY', Hour.s='Hour')
			#
			dsAll <- EddyDataWithPosix.F
			# construct in a way so that that in each seasons there are not enough valid values in 98
			nRec <- max(usControlUstarSubsetting()$minRecordsWithinSeason, usControlUstarSubsetting()$taClasses*usControlUstarSubsetting()$minRecordsWithinTemp) -50
			dsAll$seasonFactor <- usCreateSeasonFactorMonthWithinYear(dsAll$DateTime)
			dsFew <- ddply(dsAll, .(seasonFactor), function(dss){
				isValid <- usGetValidUstarIndices(dss)
				if( sum(isValid) >= nRec)
					dss$NEE[isValid][(nRec):sum(isValid)] <- NA
				#print(dss$seasonFactor[1])
				#print(nrow(dss))
				dss
			})
			dsFew$seasonFactor <- NULL
			dsFew <- arrange(dsFew, DateTime)
			dsComb <- rbind(dsFew,EddyDataWithPosix.F99)
			EddyProc.C <- sEddyProc$new('DE-Tha', dsComb, c('NEE','Rg','Tair','VPD','Ustar'))
			expect_warning(
			res <- EddyProc.C$sEstUstarThreshold(
								seasonFactor.v = usCreateSeasonFactorMonthWithinYear(EddyProc.C$sDATA$sDateTime) 								
								)
					)					
			expect_true( all(res$seasonAggregation$seasonAgg == res$seasonAggregation$seasonAgg[1] ))
			expect_equal( res$uStarTh$uStar[1], 0.43, tolerance = 0.01, scale = 1 )	# regresssion test: 0.42 by former run
			res98 <- subset(res$seasonYear, seasonYear==1998)			
			expect_equal( res98$uStarAggr[1], res98$uStarPooled, tolerance = 0.01, scale = 1 )	# regresssion test: 0.42 by former run
			res99 <- subset(res$seasonYear, seasonYear==1999)			
			expect_equal( res99$uStarAggr[1], res99$uStarMaxSeason, tolerance = 0.01, scale = 1 )	# regresssion test: 0.42 by former run
			expect_equal(EddyProc.C$sDATA$tempBin, res$bins$tempBin)
			#
			#EddyProc.C$sPlotNEEVersusUStarForSeason(res$season$season[5])			
		})


