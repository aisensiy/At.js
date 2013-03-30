###
  Implement Github like autocomplete mentions
  http://ichord.github.com/At.js

  Copyright (c) 2013 chord.luo@gmail.com
  Licensed under the MIT license.
###

( (factory) ->
  # Uses AMD or browser globals to create a jQuery plugin.
  # It does not try to register in a CommonJS environment since
  # jQuery is not likely to run in those environments.
  #
  # form [umd](https://github.com/umdjs/umd) project
  if typeof define is 'function' and define.amd
    # Register as an anonymous AMD module:
    define ['jquery'], factory
  else
    # Browser globals
    factory window.jQuery
) ($) ->

  # At.js will use this class to mirror the inputor for catching the offset of the caret(key char here).
  #
  # @example
  #   mirror = new Mirror($("textarea#inputor"))
  #   html = "<p>We will get the rect of <span>@</span>icho</p>"
  #   mirror.create(html).get_flag_rect()
  class Mirror
    css_attr: [
      "overflowY", "height", "width", "paddingTop", "paddingLeft",
      "paddingRight", "paddingBottom", "marginTop", "marginLeft",
      "marginRight", "marginBottom","fontFamily", "borderStyle",
      "borderWidth","wordWrap", "fontSize", "lineHeight", "overflowX",
      "text-align",
    ]

    # @param $inputor [Object] The jQuery object of the inputor
    constructor: (@$inputor) ->

    # 克隆输入框的样式
    #
    # @return [Object] 返回克隆得到样式
    copy_inputor_css: ->
      css =
        position: 'absolute'
        left: -9999
        top:0
        zIndex: -20000
        'white-space': 'pre-wrap'
      $.each @css_attr, (i,p) =>
        css[p] = @$inputor.css p
      css

    # create a `div` element as the mirror of the inputor
    #
    # @param html [String] The content that converted into HTML from inputor.
    #   This is for marking `flag` (@, etc.)
    #
    # @return [Object] Current mirror object
    create: (html) ->
      @$mirror = $('<div></div>')
      @$mirror.css this.copy_inputor_css()
      @$mirror.html(html)
      @$inputor.after(@$mirror)
      this

    # Get offset of the flap
    #
    # @return [Object] The offset
    #   {left: 0, top: 0, bottom: 0}
    #   from `top` to `bottom` is the line height.
    get_flag_rect: ->
      $flag = @$mirror.find "span#flag"
      pos = $flag.position()
      rect = {left: pos.left, top: pos.top, bottom: $flag.height() + pos.top}
      @$mirror.remove()
      rect


  KEY_CODE =
    DOWN: 40
    UP: 38
    ESC: 27
    TAB: 9
    ENTER: 13

  # Functions set for handling and rendering the data.
  # Others developers can override these methods to tweak At.js such as matcher.
  # We can override them in `callbacks` settings.
  #
  # @mixin
  #
  # The context of these functions is `$.atwho.Controller` object and they are called in this sequences:
  #
  # [data_refactor, matcher, filter, remote_filter, sorter, tpl_evl, highlighter, selector]
  #
  DEFAULT_CALLBACKS =

    # It would be called to restrcture the data when reg a `flag`("@", etc).
    # In default, At.js will convert it to a Hash Array.
    #
    # @param data [Array] Given data in `settings`
    #
    # @return [Array] Data after refactor.
    data_refactor: (data) ->
      return data if not $.isArray(data)
      $.map data, (item, k) ->
        if not $.isPlainObject item
          item = {name:item}
        return item

    # It would be called to match the `flag`
    #
    # @param flag [String] current `flag` ("@", etc)
    # @param subtext [String] Text from start to current caret position.
    #
    # @return [String] Matched string.
    matcher: (flag, subtext) ->
      regexp = new RegExp flag+'([A-Za-z0-9_\+\-]*)$|'+flag+'([^\\x00-\\xff]*)$','gi'
      match = regexp.exec subtext
      matched = null
      if match
        matched = if match[2] then match[2] else match[1]
      matched

    # ---------------------

    # Filter data by matched string.
    #
    # @param query [String] Matched string.
    # @param data [Array] data list
    # @param search_key [String] key word for seaching.
    #
    # @return [Array] result data.
    filter: (query, data, search_key) ->
      $.map data, (item,i) =>
        name = if $.isPlainObject(item) then item[search_key] else item
        item if name.toLowerCase().indexOf(query) >= 0

    # When `data` is string type, At.js using it as a URL to lanuch a Ajax request.
    #
    # @param params [Hash] Query for Ajax. {q: query, limit: 5}
    # @param url [String] URL to request data.
    # @param render_view [Function] render page callback.
    remote_filter: (params, url, render_view) ->
      $.ajax url,
        data: params
        success: (data) ->
          render_view(data)

    # Sorter data of course.
    #
    # @param query [String] matched string
    # @param items [Array] data that was refactored
    # @param search_key [String] key word to search
    #
    # @return [Array] sorted data
    sorter: (query, items, search_key) ->
      if !query
        return items.sort (a, b) ->
          if a[search_key].toLowerCase() > b[search_key].toLowerCase() then 1 else -1

      results = []

      for item in items
        text = item[search_key]
        item.atwho_order = text.toLowerCase().indexOf query
        results.push(item)

      results.sort (a,b) ->
        a.atwho_order - b.atwho_order

      results = for item in results
        delete item["atwho_order"]
        item


    # Eval template for every single item in display list.
    #
    # @param tpl [String] The template string.
    # @param map [Hash] Data map to eval.
    tpl_eval: (tpl, map) ->
      try
        el = tpl.replace /\$\{([^\}]*)\}/g, (tag,key,pos) ->
          map[key]
      catch error
        ""

    # Hightlight the `matched query` string.
    #
    # @param li [String] HTML String after eval.
    # @param query [String] matched query.
    #
    # @return [String] hightlighted string.
    highlighter: (li, query) ->
      return li if not query
      li.replace new RegExp(">\\s*(\\w*)(" + query.replace("+","\\+") + ")(\\w*)\\s*<", 'ig'), (str,$1, $2, $3) ->
          '> '+$1+'<strong>' + $2 + '</strong>'+$3+' <'

    # What to do after use choose a item.
    #
    # @param $li [jQuery Object] Chosen item
    selector: ($li) ->
      this.replace_str($li.data("value") || "") if $li.length > 0


  # At.js central contoller(searching, matching, evaluating and rendering.)
  class Controller

    # @param inputor [HTML DOM Object] `input` or `textarea`
    constructor: (inputor) ->
      @settings     = {}
      @pos          = 0
      @flags        = null
      @current_flag = null
      @query        = null

      @$inputor = $(inputor)
      @mirror = new Mirror(@$inputor)
      @view = new View(this, @$el)
      this.listen()

    # binding jQuery events of `inputor`'s
    listen: ->
      @$inputor
        .on 'keyup.atwho', (e) =>
          this.on_keyup(e)
        .on 'keydown.atwho', (e) =>
          this.on_keydown(e)
        .on 'scroll.atwho', (e) =>
          @view.hide()
        .on 'blur.atwho', (e) =>
          @view.hide this.get_opt("display_timeout")

    # At.js 可以对每个输入框绑定不同的监听标记. 比如同时监听 "@", ":" 字符
    # 并且通过不同的 `settings` 给予不同的表现行为, 比如插入不同的内容(即不同的渲染模板)
    #
    # 控制器初始化的时候会将默认配置当作一个所有标记共有的配置. 而每个标记只存放针对自己的特定配置.
    # 搜索配置的时候, 将先寻找标记里的配置. 如果找不到则去公用的配置里找.
    #
    # 当输入框已经注册了某个字符后, 再对该字符进行注册将会更新其配置, 比如改变 `data`, 其它的配置不变.
    #
    # @param flag [String] 要监听的字符
    # @param settings [Hash] 配置哈希值
    reg: (flag, settings) ->
      @current_flag = flag
      current_settings = if @settings[flag]
        @settings[flag] = $.extend {}, @settings[flag], settings
      else
        @settings[flag] = $.extend {}, $.fn.atwho.default, settings

      current_settings["data"] = this.callbacks("data_refactor").call(this, current_settings["data"])

      this


    # 将自定义的 `jQueryEvent` 事件代理到当前输入框( inputor )
    # 这个方法会自动为事件添加名为 `atwho` 的命名域(namespace), 并且将当前上下为作为最后一个参数传入.
    #
    # @example
    #   this.trigger "roll_n_rock", [1,2,3,4]
    #   # 对应的输入框可以如下监听事件.
    #   $inputor.on "rool_n_rock", (e, one, two, three, four) ->
    #     console.log one, two, three, four
    #
    # @param name [String] 事件名称
    # @param data [Array] 传递给回调函数的数据.
    trigger: (name, data) ->
      data ||= []
      data.push this
      @$inputor.trigger "#{name}.atwho", data

    # get or set current data which would be shown on the list view.
    #
    # @param data [Array] set data
    # @return [Array|undefined] 当前数据, 数据元素一般为 Hash 对象.
    data: (data)->
      if data
        @$inputor.data("atwho-data", data)
      else
        @$inputor.data("atwho-data")

    # At.js 允许开发者自定义控制器使用的一些功能函数
    #
    # @param func_name [String] 回调的函数名
    # @return [Function] 该回调函数
    callbacks: (func_name)->
      func = this.get_opt("callbacks")[func_name]
      func = DEFAULT_CALLBACKS[func_name] unless func
      func

    # 由于可以绑定多字符, 但配置却不相同, 而且有公用配置.所以会根据当前标记获得对应的配置
    #
    # @param key [String] 某配置项的键名
    # @param default_value [?] 没有找到任何值后自定义的默认值
    # @return [?] 配置项的值
    get_opt: (key, default_value) ->
      try
        @settings[@current_flag][key]
      catch e
        null

    # 获得标记字符在输入框中的位置
    #
    # @return [Hash] 位置信息. {top: y, left: x, bottom: bottom}
    rect: ->
      $inputor = @$inputor
      if document.selection # for IE full
        Sel = document.selection.createRange()
        x = Sel.boundingLeft + $inputor.scrollLeft()
        y = Sel.boundingTop + $(window).scrollTop() + $inputor.scrollTop()
        bottom = y + Sel.boundingHeight
          # -2 : for some font style problem.
        return {top:y-2, left:x-2, bottom:bottom-2}

      format = (value) ->
        value.replace(/</g, '&lt')
        .replace(/>/g, '&gt')
        .replace(/`/g,'&#96')
        .replace(/"/g,'&quot')
        .replace(/\r\n|\r|\n/g,"<br />")

      ### 克隆完inputor后将原来的文本内容根据
        @的位置进行分块,以获取@块在inputor(输入框)里的position
      ###
      start_range = $inputor.val().slice(0,@pos - 1)
      html = "<span>"+format(start_range)+"</span>"
      html += "<span id='flag'>?</span>"

      ###
        将inputor的 offset(相对于document)
        和@在inputor里的position相加
        就得到了@相对于document的offset.
        当然,还要加上行高和滚动条的偏移量.
      ###
      offset = $inputor.offset()
      at_rect = @mirror.create(html).get_flag_rect()

      x = offset.left + at_rect.left - $inputor.scrollLeft()
      y = offset.top - $inputor.scrollTop()
      bottom = y + at_rect.bottom
      y += at_rect.top

      # bottom + 2: for some font style problem
      return {top:y,left:x,bottom:bottom + 2}

    # 捕获标记字符后的字符串
    #
    # @return [Hash] 该字符串的信息, 包括在输入框中的位置. {'text': "hello", 'head_pos': 0, 'end_pos': 0}
    catch_query: ->
      content = @$inputor.val()
      ##获得inputor中插入符的position.
      caret_pos = @$inputor.caretPos()
      ### 向在插入符前的的文本进行正则匹配
       * 考虑会有多个 @ 的存在, 匹配离插入符最近的一个###
      subtext = content.slice(0,caret_pos)

      query = null
      $.each @settings, (flag, settings) =>
        query = this.callbacks("matcher").call(this, flag, subtext)
        if query?
          @current_flag = flag
          return false

      if typeof query is "string" and query.length <= 20
        start = caret_pos - query.length
        end = start + query.length
        @pos = start
        query = {'text': query.toLowerCase(), 'head_pos': start, 'end_pos': end}
        this.trigger "matched", [@current_flag, query.text]
      else
        @view.hide()

      @query = query

    # 将选中的项的`data-value` 内容插入到输入框中
    #
    # @param str [String] 要插入的字符串, 一般为 `data-value` 的值.
    replace_str: (str) ->
      $inputor = @$inputor
      source = $inputor.val()
      flag_len = if this.get_opt("display_flag") then 0 else @current_flag.length
      start_str = source.slice 0, (@query['head_pos'] || 0) - flag_len
      text = "#{start_str}#{str} #{source.slice @query['end_pos'] || 0}"

      $inputor.val text
      $inputor.caretPos start_str.length + str.length + 1
      $inputor.change()

    on_keyup: (e) ->
      switch e.keyCode
        when KEY_CODE.ESC
          e.preventDefault()
          @view.hide()
        when KEY_CODE.DOWN, KEY_CODE.UP
          $.noop()
        else
          this.look_up()
      e.stopPropagation()

    on_keydown: (e) ->
      return if not @view.visible()
      switch e.keyCode
        when KEY_CODE.ESC
          e.preventDefault()
          @view.hide()
        when KEY_CODE.UP
          e.preventDefault()
          @view.prev()
        when KEY_CODE.DOWN
          e.preventDefault()
          @view.next()
        when KEY_CODE.TAB, KEY_CODE.ENTER
          return if not @view.visible()
          e.preventDefault()
          @view.choose()
        else
          $.noop()
      e.stopPropagation()

    # 将处理完的数据显示到下拉列表中
    #
    # @param data [Array] 处理过后的数据列表
    render_view: (data) ->
      search_key = this.get_opt("search_key")
      data = this.callbacks("sorter").call(this, @query.text, data, search_key)
      data = data.slice(0, this.get_opt('limit'))

      this.data(data)
      @view.render data

    remote_call: (data, query) ->
      params =
          q: query.text
          limit: this.get_opt("limit")
      _callback = (data) ->
        this.render_view data
      _callback = $.proxy _callback, this
      this.callbacks('remote_filter').call(this, params, data, _callback)


    # 根据关键字搜索数据
    look_up: ->
      query = this.catch_query()
      return no if not query

      data = this.get_opt("data")
      search_key = this.get_opt("search_key")
      if typeof data is "string"
        this.remote_call(data, query)
      else if (data = this.callbacks('filter').call(this, query.text, data, search_key))
        this.render_view data
      else
          @view.hide()
      $.noop()


  # 操作下拉列表所有表现行为的类
  # 所有的这个类的对象都只操作一个视图.
  class View

    # @param controller [Object] 控制器对象.
    constructor: (@controller) ->
      @id = @controller.get_opt("view_id") || "at-view"
      @timeout_id = null
      @$el = $("##{@id}")
      this.create_view()

    # 如果试图还不存在,则创建一个新的视图
    create_view: ->
      return if this.exist()
      tpl = "<div id='#{@id}' class='at-view'><ul id='#{@id}-ul'></ul></div>"
      $("body").append(tpl)
      @$el = $("##{@id}")

      $menu = @$el.find('ul')
      $menu.on 'mouseenter.view','li', (e) ->
        $menu.find('.cur').removeClass 'cur'
        $(e.currentTarget).addClass 'cur'
      .on 'click', (e) =>
        e.stopPropagation()
        e.preventDefault()
        @$el.data("_view").choose()


    # 判断视图是否存在
    #
    # @return [Boolean]
    exist: ->
      $("##{@id}").length > 0

    # 判断视图是否显示中
    #
    # @return [Boolean]
    visible: ->
      @$el.is(":visible")

    # 选择某项的操作
    choose: ->
      $li = @$el.find ".cur"
      @controller.callbacks("selector").call(@controller, $li)
      @controller.trigger "choose", [$li]
      this.hide()

    # 重置视图在页面中的位置.
    reposition: ->
      rect = @controller.rect()
      if rect.bottom + @$el.height() - $(window).scrollTop() > $(window).height()
          rect.bottom = rect.top - @$el.height()
      offset = {left:rect.left, top:rect.bottom}
      @$el.offset offset
      @controller.trigger "reposition", [offset]

    next: ->
      cur = @$el.find('.cur').removeClass('cur')
      next = cur.next()
      next = $(@$el.find('li')[0]) if not next.length
      next.addClass 'cur'

    prev: ->
      cur = @$el.find('.cur').removeClass('cur')
      prev = cur.prev()
      prev = @$el.find('li').last() if not prev.length
      prev.addClass('cur')

    show: ->
      @$el.show() if not this.visible()
      this.reposition()

    hide: (time) ->
      if isNaN time
        @$el.hide() if this.visible()
      else
        callback = =>
          this.hide()
        clearTimeout @timeout_id
        @timeout_id = setTimeout callback, time

    clear: ->
      @$el.find('ul').empty()

    render: (list) ->
      return no if not $.isArray(list)
      if list.length <= 0
        this.hide()
        return yes

      this.clear()
      @$el.data("_view",this)

      $ul = @$el.find('ul')
      tpl = @controller.get_opt('tpl', DEFAULT_TPL)

      $.each list, (i, item) =>
        li = @controller.callbacks("tpl_eval").call(@controller, tpl, item)
        $li = $ @controller.callbacks("highlighter").call(@controller, li, @controller.query.text)
        $li.data("info", item)
        $ul.append $li

      this.show()
      $ul.find("li:eq(0)").addClass "cur"


  DEFAULT_TPL = "<li data-value='${name}'>${name}</li>"

  $.fn.atwho = (flag, options) ->
    @.filter('textarea, input').each () ->
      $this = $(this)
      data = $this.data "atwho"

      $this.data 'atwho', (data = new Controller(this)) if not data
      data.reg flag, options

  $.fn.atwho.Controller = Controller
  $.fn.atwho.View = View
  $.fn.atwho.Mirror = Mirror
  $.fn.atwho.default =
      data: null
      search_key: "name"
      callbacks: DEFAULT_CALLBACKS
      limit: 5
      display_flag: yes
      display_timeout: 300
      tpl: DEFAULT_TPL
