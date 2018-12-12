'*
'* Utilities for creating dialogs
'*

'** Credit: Plex Roku https://github.com/plexinc/roku-client-public

Function createBaseDialog() As Object

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, GetViewController())

    obj.Show = dialogShow
    obj.HandleMessage = dialogHandleMessage
    obj.Refresh = dialogRefresh
    obj.SetButton = dialogSetButton

	obj.enableOverlay = true

    ' Properties that can be set by the caller/subclass
    obj.Facade = invalid
    obj.Buttons = []
    obj.HandleButton = invalid
    obj.Title = invalid
    obj.Text = invalid
    obj.Item = invalid

    obj.Result = invalid

    obj.ScreensToClose = []

    return obj
End Function

Sub dialogSetButton(command, text)
    for each button in m.Buttons
        button.Reset()
        if button.Next() = command then
            button[command] = text
            return
        end if
    next

    button = {}
    button[command] = text
    m.Buttons.Push(button)
End Sub

Sub dialogRefresh()
    ' There's no way to change (or clear) buttons once the dialog has been
    ' shown, so create a brand new dialog.

    if m.Screen <> invalid then
        overlay = true
        Debug("Overlaying dialog")
        m.ScreensToClose.Unshift(m.Screen)
    else
        Debug("Creating new dialog")
        overlay = false
    end if

    m.Screen = CreateObject("roMessageDialog")
    m.Screen.SetMessagePort(m.Port)
    m.Screen.SetMenuTopLeft(true)
    m.Screen.EnableBackButton(true)

	m.Screen.EnableOverlay(true)
    
    if m.Title <> invalid then m.Screen.SetTitle(m.Title)
    if m.Text <> invalid then m.Screen.SetText(m.Text)

    if m.Buttons.Count() = 0 then
        m.Buttons.Push({ok: "Ok"})
    end if

    buttonCount = 0
    m.ButtonCommands = []
    for each button in m.Buttons
        button.Reset()
        cmd = button.Next()
        m.ButtonCommands[buttonCount] = cmd
        if button[cmd] = "_rate_" then
            m.Screen.AddRatingButton(buttonCount, m.Item.UserRating, m.Item.StarRating, "")
        else
            m.Screen.AddButton(buttonCount, button[cmd])
        end if
        buttonCount = buttonCount + 1
    next

    m.Screen.Show()
End Sub

Sub dialogShow(blocking=false)
    if m.Facade <> invalid then
        m.ScreensToClose.Unshift(m.Facade)
    end if

    m.ScreenName = "Dialog: " + tostr(m.Title)
    m.ViewController.AddBreadcrumbs(m, invalid)
    m.ViewController.UpdateScreenProperties(m)
    m.ViewController.PushScreen(m)

    ' We'd prefer to always use the global message port, but there are some
    ' places where we use dialogs that it would be incredibly difficult to
    ' have dialog.Show() return immediately. In those cases, we'll create
    ' our own message port and show the dialog in a blocking fashion.

    if blocking then
        m.Port = CreateObject("roMessagePort")
    end if

    m.Refresh()

    if blocking then
        while m.ScreenID = m.ViewController.Screens.Peek().ScreenID
            msg = wait(0, m.Port)
            m.HandleMessage(msg)
        end while
    end if
End Sub

Function dialogHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roMessageDialogEvent" then
        handled = true
        closeScreens = false

        if msg.isScreenClosed() then
            closeScreens = true
            m.ViewController.PopScreen(m)
        else if msg.isButtonPressed() then
            command = m.ButtonCommands[msg.getIndex()]
            Debug("Button pressed: " + tostr(command))
            done = true
            if m.HandleButton <> invalid then
                done = m.HandleButton(command, msg.getData())
            end if
            if done then
                m.Result = command
                m.ScreensToClose.Push(m.Screen)
                closeScreens = true
            end if
        end if

        ' Fun fact, if we close the facade before the event loop, the
        ' EnableBackButton call loses its effect and pressing back exits the
        ' parent screen instead of just the dialog.
        if closeScreens then
            for each screen in m.ScreensToClose
                screen.Close()
            next
            m.ScreensToClose.Clear()
        end if
    end if

    return handled
End Function