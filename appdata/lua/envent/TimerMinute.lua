--[[
每分钟会被触发一次的脚本


下面的代码为我当前接待喵逻辑使用的代码，可以重写也可以按自己需求进行更改
详细请参考readme
]]

if cqGetLoginQQ() ~= 751323264 then return end--仅限官方群里的机器人号用这个功能

local time = os.date("*t")

lowSpace = 10 --剩余空间多少G

function getSpaceOk()
    return apiGetHardDiskFreeSpace("D") > 1024 * lowSpace
end

if time.min == 0 and not getSpaceOk() then
    cqSendGroupMessage(567145439,
    cqCode_At(961726194).."你的小垃圾服务器空间只有"..tostring(apiGetHardDiskFreeSpace("D")).."M空间了知道吗？快去清理")
end

if time.min == 59 and time.hour == 2 and getSpaceOk() then
    cqSendGroupMessage(241464054,"一分钟后，将自动进行服务器例行重启与资源世界回档，请注意自己身上的物品")
    apiTcpSend("一分钟后，将自动进行服务器例行重启与资源世界回档，请注意自己身上的物品")
end

if time.min == 0 and time.hour == 3 and getSpaceOk() then
    apiTcpSend("cmdstop")
end

if time.min == 0 and time.hour == 5 then
    apiTcpSend("cmdworld create mine")
end


function checkGitHub(url,save)
    local githubRss = apiHttpGet(url)
    if githubRss or githubRss ~= "" then--获取成功的话
        local xml2lua = loadfile(apiGetPath().."/data/app/com.papapoi.ReceiverMeow/lua/require/xml2lua.lua")()
        --Uses a handler that converts the XML to a Lua table
        local handler = loadfile(apiGetPath().."/data/app/com.papapoi.ReceiverMeow/lua/require/xmlhandler/tree.lua")()
        local parser = xml2lua.parser(handler)
        parser:parse(githubRss)
        local lastUpdate = handler.root.feed.updated
        if lastUpdate and lastUpdate ~= apiXmlGet("settings",save) then
            apiXmlSet("settings",save,lastUpdate)
            for i,j in pairs(handler.root.feed.entry) do
                --缩短网址
                local shortUrl = apiHttpPost("https://git.io/create","url="..j.link._attr.href:urlEncode())
                shortUrl = (not shortUrl or shortUrl == "") and j.link._attr.href or "https://biu.papapoi.com/"..shortUrl

                --返回结果
                local toSend = "更新时间(UTC)："..(lastUpdate):gsub("T"," "):gsub("Z"," ").."\r\n"..
                "提交内容："..j.title.."\r\n"..
                "查看变动代码："..shortUrl
                return true,toSend
            end
        end
    end
end

function checkGitRelease(url,save)
    local release = apiHttpGet(url)
    local d,r,e = jsonDecode(release)
    if not r or not d then return end
    if d.id and tostring(d.id) ~= apiXmlGet("settings",save) then
        apiXmlSet("settings",save,tostring(d.id))
        --缩短网址
        local shortUrl = apiHttpPost("https://git.io/create","url="..d.html_url:urlEncode())
        shortUrl = (not shortUrl or shortUrl == "") and d.html_url or "https://biu.papapoi.com/"..shortUrl

        --返回结果
        local toSend = "更新时间(UTC)："..(d.created_at):gsub("T"," "):gsub("Z"," ").."\r\n"..
        "版本："..d.tag_name.."\r\n"..
        d.name.."\r\n"..
        d.body.."\r\n"..
        "查看更新："..shortUrl
        return true,toSend
    end
end

--检查GitHub项目是否有更新
if time.min % 10 == 0 then--十分钟检查一次
    local r,t = checkGitHub("https://github.com/chenxuuu/receiver-meow/commits/master.atom","githubLastUpdate")
    if r and t then
        local text = "接待喵lua插件在GitHub上有更新啦\r\n"..t
        cqSendGroupMessage(567145439, text)
    end

    r,t = checkGitRelease("https://api.github.com/repos/chenxuuu/receiver-meow/releases/latest","githubRelease")
    if r and t then
        local text = "接待喵lua插件发现插件版本更新\r\n"..t
        cqSendGroupMessage(931546484, text)
    end
end

local lastLive = tonumber(apiGetVar("liveGetting")) or 0
if lastLive < os.time() then--循环检查
    local beginTime = os.time()
    setMaxSecond(300)--更改超时时间
    apiSetVar("liveGetting",tostring(os.time()+300))--超时时间最大240秒，防止卡死
    cqAddLoger(0, "直播检查", "开始")


    function v2bAll(channels)
        local cs = {}
        local ds = {}
        for i=1,#channels do
            table.insert(cs,channels[i][1])
            ds[channels[i][1]] = channels[i][2]
        end
        local html = apiHttpGet("https://y2b.papapoi.com/mapi?c="..table.concat(cs,","),nil,60000)

        if not html or html == "" then return end--获取失败了
        local liveInfos,r,e = jsonDecode(html)--解析接口结果
        if not r or not liveInfos then return end --获取失败了
        cqAddLoger(0, "y2b", "服务器花费时间"..tostring(liveInfos.time))

        for i,j in pairs(liveInfos.data) do

            while true do
                if j.error then
                    cqAddLoger(0, "y2b检查返回错误", j.error)
                    break
                end

                local isopen = j.live
                local lastStatus = apiXmlGet("settings","youtuber_"..i)--获取上次状态
                if isopen then
                    if lastStatus == "live" then break end--上次提醒过了
                    apiXmlSet("settings","youtuber_"..i,"live")
                    local html = apiHttpGet("https://y2b.papapoi.com/bot?pw="..apiXmlGet("settings","tgbotpw").."&t=image"..
                                "&text="..string.urlEncode("频道："..ds[i].."，"..
                                "标题："..j.title.."，"..
                                "youtube："..j.url).."&image="..string.urlEncode(j.thumbnail))
                    cqSendGroupMessage(261037783,
                    image(j.thumbnail:gsub("i.ytimg.com","y2b.papapoi.com")).."\r\n"..
                    "频道："..ds[i].."\r\n"..
                    "标题："..j.title.."\r\n"..
                    "y2b："..j.url)
                    cqAddLoger(0, "直播检查", i.. "状态更新")
                elseif lastStatus == "live" then--没开播
                    apiXmlSet("settings","youtuber_"..i,"close live")
                end
                break
            end
        end
    end

    --b站
    function blive(id)
        id = tostring(id)
        --cqAddLoger(0, "直播检查", id .. "开始获取html")
        local html = apiHttpGet("https://api.live.bilibili.com/room/v1/Room/get_info?room_id="..id)
        --cqAddLoger(0, "直播检查", id .. "获取html结束")
        if not html or html == "" then return end--获取失败了
        local d,r,e = jsonDecode(html)
        if not r or not d then return end --获取失败了
        local lastStatus = apiXmlGet("settings","bilibili_live_"..id)--获取上次状态
        if d and d.data and d.data.live_status == 1 then
            if lastStatus == "live" then return end--上次提醒过了
            apiXmlSet("settings","bilibili_live_"..id,"live")
            return {
                title = d.data.title,
                image = d.data.user_cover,
                url = "https://live.bilibili.com/"..id,
            }
        elseif lastStatus == "live" then--没开播
            apiXmlSet("settings","bilibili_live_"..id,"close live")
        end
    end

    function checkb(id,name)
        local v = blive(id)
        if v then
            apiHttpGet("https://y2b.papapoi.com/bot?pw="..apiXmlGet("settings","tgbotpw").."&t=image"..
                        "&text="..string.urlEncode("频道："..name.."，"..
                        "标题："..v.title.."，"..
                        "b站房间："..v.url).."&image="..string.urlEncode(v.image))
            cqSendGroupMessage(261037783,
            image(v.image).."\r\n"..
            "频道："..name.."\r\n"..
            "标题："..v.title.."\r\n"..
            "b站房间："..v.url)
            cqAddLoger(0, "直播检查", tostring(id) .. "状态更新")
        end
    end

    --twitcasting
    function twitcasting(id)
        local html = apiHttpGet("https://twitcasting.tv/"..id)
        if not html or html == "" then return end--获取失败了
        local info = html:match([[TwicasPlayer.start%((.-})%);]])
        local d,r,e = jsonDecode(info)
        if not r or not d then return end --获取信息失败了

        local lastStatus = apiXmlGet("settings","twitcasting_live_"..id)--获取上次状态

        if d.isOnlive then
            if lastStatus == "live" then return end--上次提醒过了
            apiXmlSet("settings","twitcasting_live_"..id,"live")
            return "https:"..d.posterImage
        elseif lastStatus == "live" then--没开播
            apiXmlSet("settings","twitcasting_live_"..id,"close live")
        end
    end

    function checkt(id,name)
        local v = twitcasting(id)
        if v then
            apiHttpGet("https://y2b.papapoi.com/bot?pw="..apiXmlGet("settings","tgbotpw").."&t=image"..
                        "&text="..string.urlEncode("频道："..name.."，"..
                        "twitcasting：https://twitcasting.tv/"..id).."&image="..string.urlEncode(v))
            cqSendGroupMessage(261037783,
            image(v).."\r\n"..
            "频道："..name.."\r\n"..
            "twitcasting：https://twitcasting.tv/"..id)
            cqAddLoger(0, "直播检查", tostring(id) .. "状态更新")
        end
    end


    --臭dd检查fc2是否开播
    function fc2(channel)
        --cqAddLoger(0, "直播检查", channel .. "开始获取html")
        local html = apiHttpGet("https://y2b.papapoi.com/fc2?c="..channel)
        if not html or html == "" then return end--获取失败了
        local liveInfo,r,e = jsonDecode(html)--解析接口结果
        if not r or not liveInfo then return end --获取失败了

        local isopen = liveInfo.live
        local lastStatus = apiXmlGet("settings","fc2_"..channel)--获取上次状态
        if isopen then
            if lastStatus == "live" then return end--上次提醒过了
            apiXmlSet("settings","fc2_"..channel,"live")
            return {
                --cover = --不敢上图
                name = liveInfo.name,
                --url = liveInfo.url,--不敢上链接
            }
        elseif lastStatus == "live" then--没开播
            apiXmlSet("settings","fc2_"..channel,"close live")
        end
    end

    function checkfc2(channel)
        local v = fc2(channel[1])
        if v then
            apiHttpGet("https://y2b.papapoi.com/bot?pw="..apiXmlGet("settings","tgbotpw").."&t=text"..
                        "&text="..string.urlEncode("频道："..channel[2].."，"..
                        "标题："..v.name.."，"..
                        "fc2："..channel[1]))
            cqSendGroupMessage(261037783,
            "频道："..channel[2].."\r\n"..
            "标题："..v.name.."\r\n"..
            "fc2："..channel[1])
            cqAddLoger(0, "直播检查", channel[1].. "状态更新")
        end
    end



    local ddList = {
        --要监控的y2b频道
        {"UCWCc8tO-uUl_7SJXIKJACMw","那吊人🍥"}, --mea
        {"UCQ0UDLQCjY0rmuxCDE38FGg","夏色祭🏮"}, --祭
        {"UC1opHUrw8rvnsadT-iGp7Cg","湊-阿库娅⚓"}, --aqua
        {"UCrhx4PaF3uIo9mDcTxHnmIg","paryi🐇"}, --paryi
        {"UChN7P9OhRltW3w9IesC92PA","森永みう🍫"}, --miu
        {"UC8NZiqKx6fsDT3AVcMiVFyA","犬山💙"}, --犬山
        {"UCH0ObmokE-zUOeihkKwWySA","夢乃栞-Yumeno_Shiori🍄"}, --大姐
        {"UCjCrzObDrkYN-mELiCiSPAQ","夢乃栞II-Yumeno_Shiori🍄II"}, --大姐新频道
        {"UCIaC5td9nGG6JeKllWLwFLA","有栖マナ🐾"}, --mana
        {"UCn14Z641OthNps7vppBvZFA","千草はな🌼"}, --hana
        {"UC0g1AE0DOjBYnLhkgoRWN1w","本间向日葵🌻"}, --葵
        {"UCNMG8dXjgqxS94dHljP9duQ","yyut🎹"}, --yyut
        {"UCL9dLCVvHyMiqjp2RDgowqQ","高槻律🚺"}, --律
        {"UCkPIfBOLoO0hVPG-tI2YeGg","兔鞠mari🥕"}, --兔鞠mari
        {"UCIdEIHpS0TdkqRkHL5OkLtA","名取纱那🍆"}, --名取纱那
        {"UCBAopGXGGatkiB1-qFRG9WA","兔纱🎀"}, --兔纱
        {"UCZ1WJDkMNiZ_QwHnNrVf7Pw","饼叽🐥"}, --饼叽
        {"UC8gSN9D-1FL0BGBQt7p8gFQ","森永みう🍫小号"}, --森永
        {"UCzAxQCoeJrmYkHr0cHfD0Nw","yua🔯"},--yua
        {"UCerH0KOGyPaC5WueExiicZQ","杏💣🍠"},--Anzu
        {"UCPf-EnX70UM7jqjKwhDmS8g","玛格罗那🐟"},--魔王
        {"UCGcD5iUDG8xiywZeeDxye-A","织田信姬🍡"},--织田信
    }


    local bList = {
        --要监控的bilibili频道
        {14917277,"湊-阿库娅⚓"}, --夸哥
        {14052636,"夢乃栞-Yumeno_Shiori🍄"}, --大姐
        {12235923,"那吊人🍥"}, --吊人
        {4895312,"paryi🐇"}, --帕里
        {7962050,"森永みう🍫"}, --森永
        {13946381,"夏色祭🏮"}, --祭
        {10545,"A姐💽"}, --adogsama
        {12770821,"千草はな🌼"}, --hana
        {3822389,"有栖マナ🐾"}, --mana
        {4634167,"犬山💙"}, --犬山
        {43067,"HAN佬🦊"}, --han佬
        {21302477,"本间向日葵🌻"}, --葵
        {947447,"高槻律🚺"}, --律
        {3657657,"饼叽🐥"},   --饼叽
        {7408249,"兔纱🎀"}, --兔纱
        {21602686,"新科娘☭"},--新科娘
        {80387576,"织田信姬🍡"},--织田信
    }

    local tList = {
        --要监控的twitcasting频道
        {"kaguramea_vov","那吊人🍥"}, --吊人
        {"morinaga_miu","森永miu🍫"}, --miu
        {"norioo_","海苔男🍡"}, --海苔男
        {"natsuiromatsuri","夏色祭🏮"},--夏色祭
        {"kagura_pepper","神乐七奈🌶"}, --狗妈
        {"c:yumeno_shiori","shiori大姐🍄"}, --p家大姐
        {"maturin_love221","爱小姐☂︎"}, --test
        {"nana_kaguraaa","神乐七奈🌶"}, --狗妈
        {"re2_takatsuki","高槻律🚺"},--律
        {"hukkatunoyuyuta","ゆゆうた🎹"},--yyut
        {"merrysan_cas_","球王🏀"},--球王
    }

    local fc2List = {
        --要监控的fc2频道
        {"78847652","shiori🍄"}, --大姐
    }

    --遍历查询
    v2bAll(ddList)
    for i=1,#bList do
        checkb(bList[i][1],bList[i][2])
    end
    for i=1,#tList do
        checkt(tList[i][1],tList[i][2])
    end
    for i=1,#fc2List do
        checkfc2(fc2List[i])
    end

    apiSetVar("liveGetting","0")
    cqAddLoger(0, "直播检查", "结束，耗时"..tostring(os.time()-beginTime).."秒")
end
