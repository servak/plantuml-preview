{PLANTUML_PREVIEW_PROTOCOL, PlantumlPreviewView} = require './plantuml-preview-view'
url = require 'url'

{CompositeDisposable} = require 'atom'

module.exports =
  config:
    liveUpdate:
      type: 'integer'
      default: 1500
    configPath:
      type: 'string'
      default: ""
    jarPath:
      type: 'string'
      default: "~/.jar/plantuml.jar"
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-plantuml-preview:toggle': => @toggle()

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is PLANTUML_PREVIEW_PROTOCOL

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        new PlantumlPreviewView(editorId: pathname.substring(1))

  deactivate: ->
    @plantumlPreviewView.destroy()

  serialize: ->
    plantumlPreviewViewState: @plantumlPreviewView.serialize()

  toggle: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    uri = "#{PLANTUML_PREVIEW_PROTOCOL}//editor/#{editor.id}"

    previewPane = atom.workspace.paneForURI(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForURI(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (prevView) ->
      if prevView instanceof PlantumlPreviewView
        prevView.renderUml()
        previousActivePane.activate()
