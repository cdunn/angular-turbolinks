angular.module('ngTurbolinks', []).run(($location, $rootScope, $http, $q, $compile)->

  loadedAssets = null
  createDocument = null
  xhr_req = null
  referer = null

  triggerEvent = (name, data) ->
    event = document.createEvent 'Events'
    event.data = data if data
    event.initEvent name, true, true
    document.dispatchEvent event

  popCookie = (name) ->
    value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1].toUpperCase() or ''
    document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
    value

  rememberReferer = ->
    referer = document.location.href

  processResponse = (responseText, status, headers)->
    clientOrServerError = ->
      400 <= status < 600

    validContent = ->
      headers()["content-type"].match /^(?:text\/html|application\/xhtml\+xml|application\/xml)(?:;|$)/

    extractTrackAssets = (doc) ->
      for node in doc.head.childNodes when node.getAttribute?('data-turbolinks-track')?
        node.getAttribute('src') or node.getAttribute('href')

    assetsChanged = (doc) ->
      loadedAssets ||= extractTrackAssets document
      fetchedAssets  = extractTrackAssets doc
      fetchedAssets.length isnt loadedAssets.length or intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

    intersection = (a, b) ->
      [a, b] = [b, a] if a.length > b.length
      value for value in a when value in b

    if not clientOrServerError() and validContent()
      doc = createDocument responseText
      if doc and !assetsChanged doc
        return doc

  browserCompatibleDocumentParser = ->
    createDocumentUsingParser = (html) ->
      (new DOMParser).parseFromString html, 'text/html'

    createDocumentUsingDOM = (html) ->
      doc = document.implementation.createHTMLDocument ''
      doc.documentElement.innerHTML = html
      doc

    createDocumentUsingWrite = (html) ->
      doc = document.implementation.createHTMLDocument ''
      doc.open 'replace'
      doc.write html
      doc.close()
      doc

    # Use createDocumentUsingParser if DOMParser is defined and natively
    # supports 'text/html' parsing (Firefox 12+, IE 10)
    #
    # Use createDocumentUsingDOM if createDocumentUsingParser throws an exception
    # due to unsupported type 'text/html' (Firefox < 12, Opera)
    #
    # Use createDocumentUsingWrite if:
    #  - DOMParser isn't defined
    #  - createDocumentUsingParser returns null due to unsupported type 'text/html' (Chrome, Safari)
    #  - createDocumentUsingDOM doesn't create a valid HTML document (safeguarding against potential edge cases)
    try
      if window.DOMParser
        testDoc = createDocumentUsingParser '<html><body><p>test'
        createDocumentUsingParser
    catch e
      testDoc = createDocumentUsingDOM '<html><body><p>test'
      createDocumentUsingDOM
    finally
      unless testDoc?.body?.childNodes.length is 1
        return createDocumentUsingWrite

  extractTitleAndBody = (doc) ->
    title = doc.querySelector 'title'
    [ title?.textContent, removeNoscriptTags(doc.body), CSRFToken.get(doc).token, 'runScripts' ]

  CSRFToken =
    get: (doc = document) ->
      node:   tag = doc.querySelector 'meta[name="csrf-token"]'
      token:  tag?.getAttribute? 'content'

    update: (latest) ->
      current = @get()
      if current.token? and latest? and current.token isnt latest
        current.node.setAttribute 'content', latest

  changePage = (title, body, csrfToken, runScripts) ->
    document.title = title

    angular.element("body").replaceWith(body)
    $compile(body)($rootScope)

    CSRFToken.update csrfToken if csrfToken?
    executeScriptTags() if runScripts
    currentState = window.history.state
    triggerEvent 'page:change'
    triggerEvent 'page:update'

  executeScriptTags = ->
    scripts = Array::slice.call document.body.querySelectorAll 'script:not([data-turbolinks-eval="false"])'
    for script in scripts when script.type in ['', 'text/javascript']
      copy = document.createElement 'script'
      copy.setAttribute attr.name, attr.value for attr in script.attributes
      copy.appendChild document.createTextNode script.innerHTML
      { parentNode, nextSibling } = script
      parentNode.removeChild script
      parentNode.insertBefore copy, nextSibling
    return

  removeNoscriptTags = (node) ->
    node.innerHTML = node.innerHTML.replace /<noscript[\S\s]*?<\/noscript>/ig, ''
    node

  fetch = (url)->
    rememberReferer()

    xhr_req.resolve() if xhr_req
    xhr_req = $q.defer()

    triggerEvent 'page:fetch', url: url
    $http({
      url: url,
      method: 'GET',
      headers: {
        'Accept' : 'text/html, application/xhtml+xml, application/xml',
        'X-XHR-Referer' : referer
      },
      timeout: xhr_req.promise
    }).success((data, status, headers)->
      triggerEvent 'page:receive'
      if doc = processResponse(data, status, headers)
        changePage extractTitleAndBody(doc)...
        #reflectRedirectedUrl()
        triggerEvent 'page:load'
      else
        document.location.href = url
    ).error(->
      document.location.href = url
    )

  # Handle bug in Firefox 26/27 where history.state is initially undefined
  historyStateIsDefined =
    window.history.state != undefined or navigator.userAgent.match /Firefox\/2[6|7]/

  browserSupportsPushState =
    window.history and window.history.pushState and window.history.replaceState and historyStateIsDefined

  browserIsntBuggy =
    !navigator.userAgent.match /CriOS\//

  requestMethodIsSafe =
    popCookie('request_method') in ['GET','']

  browserSupportsTurbolinks = browserSupportsPushState and browserIsntBuggy and requestMethodIsSafe

  browserSupportsCustomEvents =
    document.addEventListener and document.createEvent

  installDocumentReadyPageEventTriggers = ->
    document.addEventListener 'DOMContentLoaded', ( ->
      triggerEvent 'page:change'
      triggerEvent 'page:update'
    ), true

  installJqueryAjaxSuccessPageUpdateTrigger = ->
    if typeof jQuery isnt 'undefined'
      jQuery(document).on 'ajaxSuccess', (event, xhr, settings) ->
        return unless jQuery.trim xhr.responseText
        triggerEvent 'page:update'

  if browserSupportsCustomEvents
    installDocumentReadyPageEventTriggers()
    installJqueryAjaxSuccessPageUpdateTrigger()

  if browserSupportsTurbolinks
    visit = fetch
    createDocument = browserCompatibleDocumentParser()
  else
    visit = (url) ->
      document.location.href = url

  $rootScope.$on("$locationChangeStart", (event, url, prev_url)->
    if url == prev_url || !triggerEvent 'page:before-change'
      event.preventDefault()
      return false
    
    visit(url)
  )
)
