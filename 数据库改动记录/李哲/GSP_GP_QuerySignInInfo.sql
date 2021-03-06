USE [qptreasuredb]
GO
/****** Object:  StoredProcedure [dbo].[GSP_GP_QuerySignInInfo]    Script Date: 05/21/2016 14:48:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





----------------------------------------------------------------------------------------------------

-- 用户签到
ALTER PROC [dbo].[GSP_GP_QuerySignInInfo]
	@dwUserID INT,
	@strErrorDescribe NVARCHAR(127) OUTPUT		-- 输出信息
AS

-- 属性设置
SET NOCOUNT ON

--变量声明
-- Sign Day 
DECLARE @SignDayNormal INT
DECLARE @SignDayVIP INT
DECLARE @LastSignDay DATETIME
DECLARE @LastSignDayNumNormal INT
DECLARE @LastSignDayNumVIP INT

--Sign info for Everyday
DECLARE @Day1RewardType INT
DECLARE @Day1RewardCount INT
DECLARE @Day2RewardType INT
DECLARE @Day2RewardCount INT
DECLARE @Day3RewardType INT
DECLARE @Day3RewardCount INT
DECLARE @Day4RewardType INT
DECLARE @Day4RewardCount INT
DECLARE @Day5RewardType INT
DECLARE @Day5RewardCount INT
DECLARE @Day6RewardType INT
DECLARE @Day6RewardCount INT
DECLARE @Day7RewardType INT
DECLARE @Day7RewardCount INT

DECLARE @Day1RewardTypeVIP INT
DECLARE @Day1RewardCountVIP INT
DECLARE @Day2RewardTypeVIP INT
DECLARE @Day2RewardCountVIP INT
DECLARE @Day3RewardTypeVIP INT
DECLARE @Day3RewardCountVIP INT
DECLARE @Day4RewardTypeVIP INT
DECLARE @Day4RewardCountVIP INT
DECLARE @Day5RewardTypeVIP INT
DECLARE @Day5RewardCountVIP INT
DECLARE @Day6RewardTypeVIP INT
DECLARE @Day6RewardCountVIP INT
DECLARE @Day7RewardTypeVIP INT
DECLARE @Day7RewardCountVIP INT

DECLARE @IsVIP  INT
DECLARE @CycleDayNum  INT
DECLARE @MaxDay INT
DECLARE @CurrentWeekNumNormal INT
DECLARE @CurrentWeekNumVIP INT
DECLARE @FirstDayCurrentWeekNormal INT   -- 当前周的星期一是第几天, 比如 第二周的第一天是第八天
DECLARE @FirstDayCurrentWeekVIP INT

DECLARE @NormalTodaySigned INT
DECLARE @VIPTodaySigned INT

DECLARE @NormalExtraBonus INT
DECLARE @VIPExtraBonus INT

-- 执行逻辑
BEGIN
	-- 这个存储过程需要返回 
	-- 1. 每天奖励, 直接从SignRewardConfig表里面获取数据
	-- 2. 每天的签到的情况, 
	--    这里需要知道, SignDayNoraml 和 SignDayVIP 和 七的倍数关系
	--    这个需要从LastSignDayNum 和 GetDate(), 来判断这个事情

	-- 初始化
	-- 默认第一周, 一个周期循环是七天
	SET @CurrentWeekNumNormal = 1
	SET @CurrentWeekNumVIP = 1
	SET @CycleDayNum = 7
	SET @FirstDayCurrentWeekNormal = 1
	SET @FirstDayCurrentWeekVIP = 1

	SET @NormalTodaySigned = 0
	SET @VIPTodaySigned = 0
	-- 普通用户查询
	SET @IsVIP = 0

    -- 获取一轮签满的天数, 这里有一个默认就是VIP 和 普通用户的签满天数是相同的, 一般设置为 7 的倍数
    SELECT @MaxDay = COUNT(*) FROM qptreasuredb.dbo.SignRewardConfig WHERE IsVIP = @IsVIP
    
	
    -- 如果是第一次签到, 那个SignLog里面没有用户的签到记录
    print convert(varchar(100), @dwUserID) + ',' + convert(varchar(5), @IsVIP)
    IF NOT EXISTS (SELECT LastSignDay, LastSignDayNum from SignLog Where UserID = @dwUserID AND IsVIP = @IsVIP)
    BEGIN
		print '4'
		SET @SignDayNormal = 1
		SET @NormalExtraBonus = 0
    END
    
    -- 签到情况判断
    -- 1. 已经签满一轮
    -- 2. 当天已经签到
    -- 3. 连签
    -- 4. 签到刷新
    ELSE
    BEGIN
        SELECT @LastSignDay= LastSignDay, @LastSignDayNumNormal = LastSignDayNum, @NormalExtraBonus = ExtraBonusSignedDay  from SignLog Where UserID = @dwUserID AND IsVIP = @IsVIP
        IF @MaxDay <= @LastSignDayNumNormal AND (DATEDIFF(DAY, @LastSignDay, GETDATE()) = 1)
        BEGIN
			print '1'
			SET @SignDayNormal = 1
			UPDATE qptreasuredb.dbo.SignLog SET LastSignDayNum = 0 WHERE UserID = @dwUserID AND IsVIP = @IsVIP
        END
		ELSE
		BEGIN 
			IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) = 0) -- All day signed, negtive means today has signed
		    BEGIN
		        SET @SignDayNormal = @LastSignDayNumNormal 
		        SET @NormalTodaySigned = 1
		    END
			ELSE IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) = 1) -- Yesterday has signed, it's the normal sign continuely 
			    BEGIN
			        SET @SignDayNormal = @LastSignDayNumNormal + 1
			    END
			ELSE IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) > 1) -- The sign in record isn't continuous, the sign will begin from 1.
			    BEGIN
					print '2'
			        SET @SignDayNormal = 1
		            UPDATE qptreasuredb.dbo.SignLog SET IsSignInInterrupt = 1 WHERE UserID = @dwUserID AND IsVIP = @IsVIP
			    END
		END
	END

    -- VIP 用户查询
    SET @IsVIP = 1
    
    IF NOT EXISTS (SELECT LastSignDay, LastSignDayNum from SignLog Where UserID = @dwUserID AND IsVIP = 1)
    BEGIN
        SET @SignDayVIP = 1
        SET @VIPExtraBonus = 0
    END
	ELSE
	BEGIN
        SELECT @LastSignDay= LastSignDay, @LastSignDayNumVIP = LastSignDayNum, @VIPExtraBonus = ExtraBonusSignedDay from SignLog Where UserID = @dwUserID AND IsVIP = @IsVIP
        
        IF @MaxDay <= @LastSignDayNumVIP AND (DATEDIFF(DAY, @LastSignDay, GETDATE()) > 0)
        BEGIN
			SET @SignDayVIP = 1
			UPDATE qptreasuredb.dbo.SignLog SET LastSignDayNum = 0 WHERE UserID = @dwUserID AND IsVIP = 1
        END
        ELSE
        BEGIN
		    IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) = 0) 
		        BEGIN
		            SET @SignDayVIP = @LastSignDayNumVIP  -- 没有可以签到的日子
		            SET @VIPTodaySigned = 1
		        END
		    ELSE IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) = 1)
		        BEGIN
		            SET @SignDayVIP = @LastSignDayNumVIP + 1
		        END
		    ELSE IF(DATEDIFF(DAY, @LastSignDay, GETDATE()) > 1)
		        BEGIN
		            SET @SignDayVIP = 1
		            UPDATE qptreasuredb.dbo.SignLog SET IsSignInInterrupt = 1 WHERE UserID = @dwUserID AND IsVIP = @IsVIP
		        END
		END
	END
	
	if (@SignDayNormal = 0) or (@SignDayVIP = 0) or (@SignDayNormal > @MaxDay) or (@SignDayVIP > @MaxDay)
	BEGIN
		SET @strErrorDescribe = '签到日期异常'
		return 23
	END
	
	-- 用户不需要知道当前是第几周, 这两个值不用返回
	print 'this check day 2' + ',' + convert(varchar(5), @signdaynormal) + ',' + convert(varchar(5), @signdayvip)
	SET @CurrentWeekNumNormal = (@SignDayNormal - 1) / @CycleDayNum 
	SET @CurrentWeekNumVIP = (@SignDayVIP - 1) / @CycleDayNum 
	
	SET @FirstDayCurrentWeekNormal = @CurrentWeekNumNormal * @CycleDayNum + 1
	SET @FirstDayCurrentWeekVIP = @CurrentWeekNumVIP * @CycleDayNum + 1
	SET @SignDayNormal = @SignDayNormal % @CycleDayNum
	SET @SignDayVIP = @SignDayVIP % @CycleDayNum
	
	print Convert(varchar(5), @SignDayNormal) + ',' + convert(varchar(5), @SignDayVIP) + ',' + convert(varchar(50), @FirstDayCurrentWeekNormal) + ',' + convert(varchar(50), @FirstDayCurrentWeekVIP)
	IF (@SignDayNormal = 0)
	BEGIN
		SET @SignDayNormal = @CycleDayNum
	END
	
	IF (@SignDayVIP = 0)
	BEGIN
		SET @SignDayVIP = @CycleDayNum
	END
	
	
	IF (@NormalTodaySigned = 1)
	BEGIN
		SET @SignDayNormal = -@SignDayNormal
	END
	
	IF (@VIPTodaySigned = 1)
	BEGIN
		SET @SignDayVIP = -@SignDayVIP
	END
	
    -- Get the value of the Normal Use
    SELECT @Day1RewardType = RewardType, @Day1RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal AND IsVIP = 0
    SELECT @Day2RewardType = RewardType, @Day2RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 1 AND IsVIP = 0
    SELECT @Day3RewardType = RewardType, @Day3RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 2 AND IsVIP = 0
    SELECT @Day4RewardType = RewardType, @Day4RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 3 AND IsVIP = 0
    SELECT @Day5RewardType = RewardType, @Day5RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 4 AND IsVIP = 0
    SELECT @Day6RewardType = RewardType, @Day6RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 5 AND IsVIP = 0
    SELECT @Day7RewardType = RewardType, @Day7RewardCount = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekNormal + 6 AND IsVIP = 0

    -- Get the value of the VIP User
    SELECT @Day1RewardTypeVIP = RewardType, @Day1RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP AND IsVIP = 1
    SELECT @Day2RewardTypeVIP = RewardType, @Day2RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 1 AND IsVIP = 1
    SELECT @Day3RewardTypeVIP = RewardType, @Day3RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 2 AND IsVIP = 1
    SELECT @Day4RewardTypeVIP = RewardType, @Day4RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 3 AND IsVIP = 1
    SELECT @Day5RewardTypeVIP = RewardType, @Day5RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 4 AND IsVIP = 1
    SELECT @Day6RewardTypeVIP = RewardType, @Day6RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 5 AND IsVIP = 1
    SELECT @Day7RewardTypeVIP = RewardType, @Day7RewardCountVIP = RewardCount From SignRewardConfig Where DayNum = @FirstDayCurrentWeekVIP + 6 AND IsVIP = 1

    -- Extra Bonus
    -- Normal Status -day2 and day7, powernum is daynum minus 1(for day2 , you should power(2, (2 - 1)))
    print 'normalextrabonus' + ',' + convert(varchar(5), @NormalExtraBonus)
    DECLARE @IsExtraBonusOverNormal INT
    SET @IsExtraBonusOverNormal = 0
    DECLARE @IsSignInInterrupt INT
    SET @IsSignInInterrupt = 0
    DECLARE @tmpBonusDay INT
    SET @tmpBonusDay = 0
    SELECT @IsExtraBonusOverNormal = IsExtraBonusOver, @IsSignInInterrupt = IsSignInInterrupt FROM SignLog WHERE UserID = @dwUserID AND IsVIP = 0
    
    -- day 2 
	SET @tmpBonusDay = 2
	
	-- DECLARE temp 
	DECLARE @temp INT
	SET @temp = POWER(2, (@tmpBonusDay - 1))
	print 'powerres' + convert(varchar(10), @temp) + 'ExtraBonusOverNormal' + convert(varchar(10), @IsExtraBonusOverNormal) + 'SignInterrupt' + convert(varchar(10), @IsSignInInterrupt) + 'SignDayNormal' + convert(varchar(10), @SignDayNormal)
    IF (@NormalExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR ((@IsExtraBonusOverNormal = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayNormal) > @tmpBonusDay) OR (@SignDayNormal = -@tmpBonusDay))) 
    BEGIN
        SET @Day2RewardType = 3
        SET @Day2RewardCount = 5
    END
    
    -- day 4    
	SET @tmpBonusDay = 4
    IF (@NormalExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR ((@IsExtraBonusOverNormal = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayNormal) > @tmpBonusDay) OR (@SignDayNormal = -@tmpBonusDay))) 
    BEGIN
        SET @Day4RewardType = 10
        SET @Day4RewardCount = 10
    END
        
    -- day 7 
    SET @tmpBonusDay = 7 
    IF (@NormalExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR ((@IsExtraBonusOverNormal = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayNormal) > @tmpBonusDay) OR (@SignDayNormal = -@tmpBonusDay))) 
    BEGIN
        SET @Day7RewardType = 12
        SET @Day7RewardCount = 1
    END
    
    DECLARE @IsExtraBonusOverVIP INT
    SET @IsExtraBonusOverVIP = 0
    SET @IsSignInInterrupt = 0
    SELECT @IsExtraBonusOverVIP = IsExtraBonusOver, @IsSignInInterrupt = IsSignInInterrupt FROM SignLog WHERE UserID = @dwUserID AND IsVIP = 1
    -- VIP status
    print 'vipextrabonus' + ',' + convert(varchar(5), @VIPExtraBonus) + ',' + convert(varchar(5), @IsSignInInterrupt) + ',' + convert(varchar(5), @SignDayVIP)
    SET @tmpBonusDay = 1
	IF (@VIPExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR (((@IsExtraBonusOverVIP = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayVIP) > @tmpBonusDay) OR (@SignDayVIP = -@tmpBonusDay))))   
    BEGIN
        SET @Day1RewardTypeVIP = 2
        SET @Day1RewardCountVIP = 1000
    END
    
    SET @tmpBonusDay = 3
	IF (@VIPExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR (((@IsExtraBonusOverVIP = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayVIP) > @tmpBonusDay) OR (@SignDayVIP = -@tmpBonusDay))))   
    BEGIN
        SET @Day3RewardTypeVIP = 10
        SET @Day3RewardCountVIP = 20
    END
    
    SET @tmpBonusDay = 6
	IF (@VIPExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR (((@IsExtraBonusOverVIP = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayVIP) > @tmpBonusDay) OR (@SignDayVIP = -@tmpBonusDay))))   
    BEGIN
        SET @Day6RewardTypeVIP = 4
        SET @Day6RewardCountVIP = 1
    END
    
    
    SET @tmpBonusDay = 7
	IF (@VIPExtraBonus & Power(2, (@tmpBonusDay - 1)) = 0) OR (((@IsExtraBonusOverVIP = 0) AND (@IsSignInInterrupt = 0) AND ((ABS(@SignDayVIP) > @tmpBonusDay) OR (@SignDayVIP = -@tmpBonusDay))))    
    BEGIN
        SET @Day7RewardTypeVIP = 3
        SET @Day7RewardCountVIP = 10   
    END




    -- Return the value of the 
    SELECT @SignDayNormal AS SignDayNormal, 
		   @SignDayVIP AS SignDayVIP, 
		   @LastSignDayNumNormal AS LastSignDayNumNormal,
		   @LastSignDayNumVIP AS LastSignDayNumVIP,
            @Day1RewardType AS Day1RewardType,
            @Day1RewardTypeVIP AS Day1RewardTypeVIP,
            @Day1RewardCount AS Day1RewardCount,
            @Day2RewardType AS Day2RewardType,
            @Day2RewardCount AS Day2RewardCount,
            @Day3RewardType AS Day3RewardType,
            @Day3RewardCount AS Day3RewardCount,
            @Day4RewardType AS Day4RewardType,
            @Day4RewardCount AS Day4RewardCount,
            @Day5RewardType AS Day5RewardType,
            @Day5RewardCount AS Day5RewardCount,
            @Day6RewardType AS Day6RewardType,
            @Day6RewardCount AS Day6RewardCount,
            @Day7RewardType AS Day7RewardType,
            @Day7RewardCount AS Day7RewardCount,
            @Day1RewardTypeVIP AS Day1RewardTypeVIP,
            @Day1RewardCountVIP AS Day1RewardCountVIP,
            @Day2RewardTypeVIP AS Day2RewardTypeVIP,
            @Day2RewardCountVIP AS Day2RewardCountVIP,
            @Day3RewardTypeVIP AS Day3RewardTypeVIP,
            @Day3RewardCountVIP AS Day3RewardCountVIP,
            @Day4RewardTypeVIP AS Day4RewardTypeVIP,
            @Day4RewardCountVIP AS Day4RewardCountVIP,
            @Day5RewardTypeVIP AS Day5RewardTypeVIP,
            @Day5RewardCountVIP AS Day5RewardCountVIP,
            @Day6RewardTypeVIP AS Day6RewardTypeVIP,
            @Day6RewardCountVIP AS Day6RewardCountVIP,
            @Day7RewardTypeVIP AS Day7RewardTypeVIP,
            @Day7RewardCountVIP AS Day7RewardCountVIP
END

RETURN 22

