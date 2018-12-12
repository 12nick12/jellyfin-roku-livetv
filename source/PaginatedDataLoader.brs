'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*
'** Credit: Plex Roku https://github.com/plexinc/roku-client-public

Function createPaginatedLoader(container, httpHandler, initialLoadSize, pageSize)
    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.names = container.names
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

	loader.httpHandler = httpHandler

    loader.contentArray = []

    keys = container.keys
    for index = 0 to keys.Count() - 1
        status = CreateObject("roAssociativeArray")
        status.content = []
        status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
        status.key = keys[index]
        status.name = loader.names[index]
        status.pendingRequests = 0
        status.countLoaded = 0

        loader.contentArray[index] = status
    end for

    ' Set up search nodes as the last row if we have any
    searchItems = [] ' container.GetSearch()
    if searchItems.Count() > 0 then
        status = CreateObject("roAssociativeArray")
        status.content = searchItems
        status.loadStatus = 0
        status.key = "_search_"
        status.name = "Search"
        status.pendingRequests = 0
        status.countLoaded = 0

        loader.contentArray.Push(status)
    end if

    ' Reorder container sections so that frequently accessed sections
    ' are displayed first. Make sure to revert the search row's dummy key
    ' to invalid so we don't try to load it.
    ' ReorderItemsByKeyPriority(loader.contentArray, RegRead("section_row_order", "preferences", ""))
    for index = 0 to loader.contentArray.Count() - 1
        status = loader.contentArray[index]
        loader.names[index] = status.name
        if status.key = "_search_" then
            status.key = invalid
        end if
    next

    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.RefreshData = loaderRefreshData
    loader.RefreshRow = loaderRefreshRow
    loader.StartRequest = loaderStartRequest
    loader.OnUrlEvent = loaderOnUrlEvent
    loader.GetPendingRequestCount = loaderGetPendingRequestCount

    ' When we know the full size of a container, we'll populate an array with
    ' dummy items so that the counts show up correctly on grid screens. It
    ' should generally provide a smoother loading experience. This is the
    ' metadata that will be used for pending items.
    loader.LoadingItem = {
        title: "Loading..."
    }

    return loader
End Function

'*
'* Load more data either in the currently focused row or the next one that
'* hasn't been fully loaded. The return value indicates whether subsequent
'* rows are already loaded.
'*
Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    extraRowsAlreadyLoaded = true
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            exit for
        else if m.contentArray[index].loadStatus < 2 AND m.contentArray[index].pendingRequests = 0 then
            if status = invalid then
                status = m.contentArray[index]
                loadingRow = index
            else
                extraRowsAlreadyLoaded = false
                exit for
            end if
        end if
    end for

    if status = invalid then return true

    ' Special case, if this is a row with static content, update the status
    ' and tell the listener about the content.
    if status.key = invalid then
        status.loadStatus = 2
        if m.Listener <> invalid then
            m.Listener.OnDataLoaded(loadingRow, status.content, 0, status.content.Count(), true)
        end if
        return extraRowsAlreadyLoaded
    end if

    startItem = status.countLoaded
    if startItem = 0 then
        count = m.initialLoadSize
    else
        count = m.pageSize
    end if

    status.loadStatus = 1
    m.StartRequest(loadingRow, startItem, count)

    return extraRowsAlreadyLoaded
End Function

Sub loaderRefreshData()
    for row = 0 to m.contentArray.Count() - 1
        status = m.contentArray[row]
        if status.key <> invalid AND status.loadStatus <> 0 then
            m.StartRequest(row, 0, m.pageSize)
        end if
    next
End Sub

Sub loaderRefreshRow(index as Integer)
    for row = 0 to m.contentArray.Count() - 1
        status = m.contentArray[row]
        if index = row and status.key <> invalid AND status.loadStatus <> 0 then
            m.StartRequest(row, 0, m.pageSize)
        end if
    next
End Sub

Function getPaginatedRequest(url, startItem, count) as Object

	urlString = url.GetString()

    ' Prepare Request
    myRequest = HttpRequest(urlString)
    myRequest.ContentType("json")
    myRequest.AddAuthorization()

	myRequest.AddParam("StartIndex", tostr(startItem))
	myRequest.AddParam("Limit", tostr(count))

	myRequest = myRequest.GetRequest()

	return myRequest

End Function

Sub loaderStartRequest(row, startItem, count)

    status = m.contentArray[row]

    request = CreateObject("roAssociativeArray")

    request.row = row
    request.startItem = startItem

	handler = m.httpHandler

	if handler.getlocalData <> invalid then

		localData = handler.getlocalData(row, status.key, startItem, count)

		if localData <> invalid then

			request.localData = localData
			status.pendingRequests = status.pendingRequests + 1

			' Fake this
			m.OnUrlEvent(invalid, request)
			return
		end If
	end If

	url = handler.getUrl(row, status.key)
    urlTransferObj = getPaginatedRequest(url, startItem, count)

    ' Associate the request with our listener's screen ID, so that any pending
    ' requests are canceled when the screen is popped.
    m.ScreenID = m.Listener.ScreenID

    if GetViewController().StartRequest(urlTransferObj, m, request) then
        status.pendingRequests = status.pendingRequests + 1
    else
        Debug("Failed to start request for row " + tostr(row) + ": " + tostr(urlTransferObj.GetUrl()))
    end if
End Sub

Sub loaderOnUrlEvent(msg, requestContext)

    status = m.contentArray[requestContext.row]
    status.pendingRequests = status.pendingRequests - 1

	handler = m.httpHandler

	if requestContext.localData <> invalid then
		container = requestContext.localData
	else
		if msg.GetResponseCode() <> 200 then
			 url = requestContext.Request.GetUrl()

			Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(url) + " - " + tostr(msg.GetFailureReason()))
			return
		end if

		container = handler.parsePagedResult(requestContext.row, status.key, requestContext.startItem, msg.GetString())
	end if

    totalSize = container.TotalCount

    if totalSize <= 0 then
        status.loadStatus = 2
        startItem = 0
        countLoaded = status.content.Count()
        status.countLoaded = countLoaded
    else

        startItem = requestContext.startItem

        countLoaded = container.Items.Count()

        if startItem <> status.content.Count() then
            Debug("Received paginated response for index " + tostr(startItem) + " of list with length " + tostr(status.content.Count()))
            metadata = container.Items
            for i = 0 to countLoaded - 1
                status.content[startItem + i] = metadata[i]
            next
        else
            status.content.Append(container.Items)
        end if

        if totalSize > status.content.Count() then
            ' We could easily fill the entire array with our dummy loading item,
            ' but it's usually just wasted cycles at a time when we care about
            ' the app feeling responsive. So make the first and last item use
            ' our dummy metadata and everything in between will be blank.
            status.content.Push(m.LoadingItem)
            status.content[totalSize - 1] = m.LoadingItem
        end if

        if status.loadStatus <> 2 then
            status.countLoaded = startItem + countLoaded
        end if

        Debug("Count loaded is now " + tostr(status.countLoaded) + " out of " + tostr(totalSize))

        if status.loadStatus = 2 AND startItem + countLoaded < totalSize then
            ' We're in the middle of refreshing the row, kick off the
            ' next request.
            m.StartRequest(requestContext.row, startItem + countLoaded, m.pageSize)
        else if status.countLoaded < totalSize then
            status.loadStatus = 1
        else
            status.loadStatus = 2
        end if
    end if

    while status.content.Count() > totalSize
        status.content.Pop()
    end while

    if countLoaded > status.content.Count() then
        countLoaded = status.content.Count()
    end if

    if status.countLoaded > status.content.Count() then
        status.countLoaded = status.content.Count()
    end if

    if m.Listener <> invalid then
        m.Listener.OnDataLoaded(requestContext.row, status.content, startItem, countLoaded, status.loadStatus = 2)
    end if
End Sub

Function loaderGetLoadStatus(row)
    return m.contentArray[row].loadStatus
End Function

Function loaderGetPendingRequestCount() As Integer
    pendingRequests = 0
    for each status in m.contentArray
        pendingRequests = pendingRequests + status.pendingRequests
    end for

    return pendingRequests
End Function