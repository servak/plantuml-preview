{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
fs = require "fs-plus"

spawn = require("child_process").spawnSync

module.exports =
  PLANTUML_PREVIEW_PROTOCOL: "plantuml-preview:"
  PlantumlPreviewView: class PlantumlPreviewView extends ScrollView
    @content: ->
      @div class: 'markdown-preview native-key-bindings', tabindex: -1

    constructor: ({@editorId}) ->
      super

      @emitter = new Emitter
      @disposables = new CompositeDisposable
      @loaded = false
      @jarPath = atom.config.get('plantuml-preview.jarPath')

      configPath = atom.config.get('plantuml-preview.configPath')
      @config = if fs.existsSync(configPath) then "-c #{configPath}" else ""

    attached: ->
      return if @isAttached
      @isAttached = true

      if @editorId?
        @resolveEditor(@editorId)

    serialize: ->
      deserializer : 'PlantumlPreviewView'
      filePath     : @getPath()
      editorId     : @editorId

    destroy: ->
      @disposables.dispose()

    onDidChangeTitle: (callback) ->
      @emitter.on 'did-change-title', callback

    onDidChangeModified: (callback) ->
      # No op to suppress deprecation warning
      new Disposable

    onDidChangeUml: (callback) ->
      @emitter.on 'did-change-uml', callback

    resolveEditor: (editorId) ->
      resolve = =>
        @editor = @editorForId(editorId)

        if @editor?
          @emitter.emit 'did-change-title' if @editor?
          @handleEvents()
        else
          # The editor this preview was created for has been closed so close
          # this preview since a preview cannot be rendered without an editor
          atom.workspace?.paneForItem(this)?.destroyItem(this)

      if atom.workspace?
        resolve()
      else
        @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

    editorForId: (editorId) ->
      for editor in atom.workspace.getTextEditors()
        return editor if editor.id?.toString() is editorId.toString()
      null

    getTitle: ->
      if @editor?
        "#{@editor.getTitle()} Preview"
      else
        "PlantUml Preview"

    renderUml: =>
      buffer = @editor.getText()
      return if buffer == ""

      @showLoading() unless @loaded

      options = [
        "-Djava.awt.headless=true",
        "-jar",
        @jarPath,
        "-tpng",
        "-pipe",
        @config
      ]

      command = spawn("java", options, {
        input: buffer
      })

      png = "data:image/png;base64," + command.stdout.toString('base64')

      @html $$$ ->
        @tag "img", {src: png}

      @loading = false

    showLoading: ->
      @loading = true
      @html $$$ ->
        @div class: 'markdown-spinner', 'Loading Uml\u2026'

    getURI: ->
      "plantuml-preview://editor/#{@editorId}"

    getPath: ->
      @editor.getPath() if @editor?

    handleEvents: ->
      atom.commands.add @element,
        'core:move-up': =>
          @scrollUp()
        'core:move-down': =>
          @scrollDown()

      changeHandler = =>
        if @timer
          clearTimeout @timer

        @timer = setTimeout(@renderUml, atom.config.get('plantuml-preview.liveUpdate'))

        # TODO: Remove paneForURI call when ::paneForItem is released
        pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
        if pane? and pane isnt atom.workspace.getActivePane()
          pane.activateItem(this)

      if @editor?
        @disposables.add @editor.getBuffer().onDidStopChanging ->
          changeHandler()
        @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
        @disposables.add @editor.getBuffer().onDidSave ->
          changeHandler()
        @disposables.add @editor.getBuffer().onDidReload ->
          changeHandler()
