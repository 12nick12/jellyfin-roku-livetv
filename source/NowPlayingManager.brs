'*
'* Manage state about what is currently playing, who is currently subscribed
'* to that information, and sending timeline information to subscribers.
'*
'** Credit: Plex Roku https://github.com/plexinc/roku-client-public

Function NowPlayingManager()
    if m.NowPlayingManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.NAVIGATION = "navigation"
        obj.FULLSCREEN_VIDEO = "fullScreenVideo"
        obj.FULLSCREEN_MUSIC = "fullScreenMusic"
        obj.FULLSCREEN_PHOTO = "fullScreenPhoto"
        obj.TIMELINE_TYPES = ["video", "music", "photo"]

        ' Members
        obj.subscribers = CreateObject("roAssociativeArray")
        obj.pollReplies = CreateObject("roAssociativeArray")
        obj.timelines = CreateObject("roAssociativeArray")
        obj.location = obj.NAVIGATION

        obj.textFieldName = invalid
        obj.textFieldContent = invalid
        obj.textFieldSecure = false

        ' Functions
        obj.UpdateCommandID = nowPlayingUpdateCommandID
        obj.AddSubscriber = nowPlayingAddSubscriber
        obj.AddPollSubscriber = nowPlayingAddPollSubscriber
        obj.RemoveSubscriber = nowPlayingRemoveSubscriber
        obj.SendTimelineToSubscriber = nowPlayingSendTimelineToSubscriber
        obj.SendTimelineToAll = nowPlayingSendTimelineToAll
        obj.CreateTimelineDataXml = nowPlayingCreateTimelineDataXml
        obj.UpdatePlaybackState = nowPlayingUpdatePlaybackState
        obj.TimelineDataXmlForSubscriber = nowPlayingTimelineDataXmlForSubscriber
        obj.WaitForNextTimeline = nowPlayingWaitForNextTimeline
        obj.SetControllable = nowPlayingSetControllable
        obj.SetFocusedTextField = nowPlayingSetFocusedTextField

        ' Initialization
        for each timelineType in obj.TIMELINE_TYPES
            obj.timelines[timelineType] = TimelineData(timelineType)
        next

        ' Singleton
        m.NowPlayingManager = obj
    end if

    return m.NowPlayingManager
End Function

Function TimelineData(timelineType As String)
    obj = CreateObject("roAssociativeArray")

    obj.type = timelineType
    obj.state = "stopped"
    obj.item = invalid

    obj.controllable = CreateObject("roAssociativeArray")
    obj.controllableStr = invalid

    obj.attrs = CreateObject("roAssociativeArray")

    obj.UpdateControllableStr = timelineDataUpdateControllableStr
    obj.SetControllable = timelineDataSetControllable

    obj.SetControllable("playPause", true)
    obj.SetControllable("stop", true)
    
    if timelineType = "video" then
        obj.SetControllable("seekTo", true)
        obj.SetControllable("stepBack", true)
        obj.SetControllable("stepForward", true)
    else if timelineType = "music" then
        obj.SetControllable("seekTo", true)
        obj.SetControllable("stepBack", true)
        obj.SetControllable("stepForward", true)
        obj.SetControllable("repeat", true)
        obj.SetControllable("shuffle", true)
    else if timelineType = "photo" then
        obj.SetControllable("shuffle", true)
    end if

    return obj
End Function

Function NowPlayingSubscriber(deviceID, connectionUrl, commandID, poll=false)
    obj = CreateObject("roAssociativeArray")

    obj.deviceID = deviceID
    obj.connectionUrl = connectionUrl
    obj.commandID = validint(commandID)

    if NOT poll then
        obj.SubscriptionTimer = createTimer()
        obj.SubscriptionTimer.SetDuration(90000)
    end if

    return obj
End Function

Sub nowPlayingUpdateCommandID(deviceID, commandID)
    subscriber = m.subscribers[deviceID]
    if subscriber <> invalid then
        subscriber.commandID = validint(commandID)
    end if
End Sub

Function nowPlayingAddSubscriber(deviceID, connectionUrl, commandID) As Boolean
    if firstOf(deviceID, "") = "" then
        Debug("Now Playing: received subscribe without an identifier")
        return false
    end if

    subscriber = m.subscribers[deviceID]

    if subscriber = invalid then
        Debug("Now Playing: New subscriber " + deviceID + " at " + tostr(connectionUrl) + " with command id " + tostr(commandID))
        subscriber = NowPlayingSubscriber(deviceID, connectionUrl, commandID)
        m.subscribers[deviceID] = subscriber
    end if

    subscriber.SubscriptionTimer.Mark()

    m.SendTimelineToSubscriber(subscriber)

    return true
End Function

Sub nowPlayingAddPollSubscriber(deviceID, commandID)
    if firstOf(deviceID, "") = "" then return

    subscriber = m.subscribers[deviceID]

    if subscriber = invalid then
        subscriber = NowPlayingSubscriber(deviceID, invalid, commandID, true)
        m.subscribers[deviceID] = subscriber
    end if
End Sub

Sub nowPlayingRemoveSubscriber(deviceID)
    if deviceID <> invalid then
        Debug("Now Playing: Removing subscriber " + deviceID)
        m.subscribers.Delete(deviceID)
    end if
End Sub

Sub nowPlayingSendTimelineToSubscriber(subscriber, xml=invalid)
    if xml = invalid then
        xml = m.CreateTimelineDataXml()
    end if

    xml.AddAttribute("commandID", tostr(subscriber.commandID))

    url = subscriber.connectionUrl + "/:/timeline"
    GetViewController().StartRequestIgnoringResponse(url, xml.GenXml(false))
End Sub

Sub nowPlayingSendTimelineToAll()
    m.subscribers.Reset()
    if m.subscribers.IsNext() then
        xml = m.CreateTimelineDataXml()
    end if
    expiredSubscribers = CreateObject("roList")

    for each id in m.subscribers
        subscriber = m.subscribers[id]
        if subscriber.SubscriptionTimer <> invalid then
            if subscriber.SubscriptionTimer.IsExpired() then
                expiredSubscribers.AddTail(id)
            else
                m.SendTimelineToSubscriber(subscriber, xml)
            end if
        end if
    next

    for each id in expiredSubscribers
        m.subscribers.Delete(id)
    next
End Sub

Sub nowPlayingUpdatePlaybackState(timelineType, item, state, time)
    timeline = m.timelines[timelineType]
    timeline.state = state
    timeline.item = item
    timeline.attrs["time"] = tostr(time)

    m.SendTimelineToAll()

    ' Send the timeline data to any waiting poll requests
    for each id in m.pollReplies
        reply = m.pollReplies[id]
        xml = m.TimelineDataXmlForSubscriber(reply.deviceID)
        reply.mimetype = MimeType("xml")
        reply.simpleOK(xml)
        reply.timeoutTimer.Active = false
        reply.timeoutTimer.Listener = invalid
    next

    m.pollReplies.Clear()

    ' Send the timeline to the item's server, if any
    if item <> invalid AND item.server <> invalid then
        item.server.Timeline(item, state, time)
    end if
End Sub

Function nowPlayingCreateTimelineDataXml()
    mc = CreateObject("roXMLElement")
    mc.SetName("MediaContainer")
    mc.AddAttribute("location", m.location)

    if m.textFieldName <> invalid then
        mc.AddAttribute("textFieldFocused", m.textFieldName)
        mc.AddAttribute("textFieldContent", m.textFieldContent)
        if m.textFieldSecure then
            mc.AddAttribute("textFieldSecure", "1")
        end if
    end if

    return mc
End Function

Function nowPlayingTimelineDataXmlForSubscriber(deviceID)
    commandID = 0
    subscriber = m.subscribers[firstOf(deviceID, "")]
    if subscriber <> invalid then commandID = subscriber.commandID

    xml = m.CreateTimelineDataXml()
    xml.AddAttribute("commandID", tostr(commandID))

    return xml.GenXml(false)
End Function

Sub nowPlayingWaitForNextTimeline(deviceID, reply)
    reply.source = reply.WAITING

    reply.ScreenID = -4
    timeoutTimer = createTimer()
    timeoutTimer.Name = "timeout"
    timeoutTimer.SetDuration(30000)
    timeoutTimer.Active = true

    reply.deviceID = deviceID
    reply.timeoutTimer = timeoutTimer
    reply.OnTimerExpired = pollOnTimerExpired
    GetViewController().AddTimer(timeoutTimer, reply)

    m.pollReplies[tostr(reply.id)] = reply
End Sub

Sub pollOnTimerExpired(timer)
    timer.Listener = invalid

    xml = NowPlayingManager().TimelineDataXmlForSubscriber(m.deviceID)
    m.mimetype = MimeType("xml")
    m.simpleOK(xml)
End Sub

Sub nowPlayingSetControllable(timelineType, name, isControllable)
    m.timelines[timelineType].SetControllable(name, isControllable)
End Sub

Sub timelineDataSetControllable(name, isControllable)
    if isControllable then
        m.controllable[name] = ""
    else
        m.controllable.Delete(name)
    end if

    m.controllableStr = invalid
End Sub

Sub timelineDataUpdateControllableStr()
    if m.controllableStr = invalid then
        m.controllableStr = box("")
        prependComma = false

        for each name in m.controllable
            if prependComma then
                m.controllableStr.AppendString(",", 1)
            else
                prependComma = true
            end if
            m.controllableStr.AppendString(name, len(name))
        next
    end if
End Sub

Sub addAttributeIfValid(elem, name, value)
    if value <> invalid then
        elem.AddAttribute(name, tostr(value))
    end if
End Sub

Sub nowPlayingSetFocusedTextField(name, content, secure)
    m.textFieldName = name
    m.textFieldContent = firstOf(content, "")
    m.textFieldSecure = secure
    m.SendTimelineToAll()
End Sub