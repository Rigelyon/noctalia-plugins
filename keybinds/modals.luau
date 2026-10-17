--!nonstrict
-- Modal Dialog Components for Keybinds Cheatsheet
local crud = require("./crud.luau")

local modals = {}

function modals.renderEditAppModal(props: {
  editAppName: string,
  editAppIcon: string,
  editTarget: { origApp: string, origSubcat: string, origBindIdx: number },
  formError: string,
  cornerRadiusScale: number,
  tr: (string, any?) -> string,
  openIconPicker: (string, (string) -> ()) -> (),
  onAppNameChange: (string) -> (),
  onAppIconChange: (string) -> (),
  onCancel: () -> (),
  onSave: (currentStore: any, newName: string, newIcon: string) -> (),
  getCustomStore: () -> any,
}): any
  local editAppName = props.editAppName
  local editAppIcon = props.editAppIcon
  local formError = props.formError
  local cornerRadiusScale = props.cornerRadiusScale or 1.0
  local tr = props.tr

  local cardChildren = {
    -- Header
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = "pencil", size = 16, color = "primary" }),
        ui.label({
          text = tr("modal.edit_app_title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("modal.cancel"),
        onClick = function()
          props.onCancel()
        end,
      }),
    }),

    -- App Name Input + Icon Picker Trigger
    ui.column({ gap = 6, align = "stretch" }, {
      ui.label({ text = tr("modal.app_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
      ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
        ui.input({
          key = "modal-edit-app-input",
          placeholder = tr("modal.app_placeholder"),
          value = editAppName,
          flexGrow = 1,
          onChange = function(val)
            props.onAppNameChange(val)
          end,
        }),
        ui.button({
          glyph = editAppIcon,
          variant = "secondary",
          tooltip = tr("modal.pick_icon"),
          onClick = function()
            props.openIconPicker(editAppIcon, function(newIcon)
              props.onAppIconChange(newIcon)
            end)
          end,
        }),
      }),
    }),
  }

  if #formError > 0 then
    table.insert(cardChildren, ui.label({
      text = formError,
      fontSize = 11,
      color = "error",
    }))
  end

  table.insert(cardChildren, ui.row({
    justify = "end",
    gap = 8,
    align = "center",
  }, {
    ui.button({
      text = tr("modal.cancel"),
      variant = "ghost",
      onClick = function()
        props.onCancel()
      end,
    }),
    ui.button({
      text = tr("modal.save"),
      variant = "primary",
      onClick = function()
        local currentStore = props.getCustomStore()
        props.onSave(currentStore, editAppName, editAppIcon)
      end,
    }),
  }))

  return ui.column({
    flexGrow = 1,
    align = "center",
    justify = "center",
    padding = 16,
  }, {
    ui.column({
      width = 460,
      radius = 12 * cornerRadiusScale,
      fill = "surface",
      padding = 20,
      gap = 12,
      align = "stretch",
    }, cardChildren),
  })
end

function modals.renderEditSubcatModal(props: {
  editSubcatName: string,
  editSubcatIcon: string,
  editSubcatParentApp: string,
  editTarget: { origApp: string, origSubcat: string, origBindIdx: number },
  formError: string,
  cornerRadiusScale: number,
  tr: (string, any?) -> string,
  openIconPicker: (string, (string) -> ()) -> (),
  onSubcatNameChange: (string) -> (),
  onSubcatIconChange: (string) -> (),
  onCancel: () -> (),
  onSave: (currentStore: any, newName: string, newIcon: string) -> (),
  getCustomStore: () -> any,
}): any
  local editSubcatName = props.editSubcatName
  local editSubcatIcon = props.editSubcatIcon
  local formError = props.formError
  local cornerRadiusScale = props.cornerRadiusScale or 1.0
  local tr = props.tr

  local cardChildren = {
    -- Header
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = "pencil", size = 16, color = "primary" }),
        ui.label({
          text = tr("modal.edit_subcat_title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("modal.cancel"),
        onClick = function()
          props.onCancel()
        end,
      }),
    }),

    -- Subcat Name Input + Icon Picker Trigger
    ui.column({ gap = 6, align = "stretch" }, {
      ui.label({ text = tr("modal.subcat_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
      ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
        ui.input({
          key = "modal-edit-subcat-input",
          placeholder = tr("modal.subcat_placeholder"),
          value = editSubcatName,
          flexGrow = 1,
          onChange = function(val)
            props.onSubcatNameChange(val)
          end,
        }),
        ui.button({
          glyph = editSubcatIcon,
          variant = "secondary",
          tooltip = tr("modal.pick_icon"),
          onClick = function()
            props.openIconPicker(editSubcatIcon, function(newIcon)
              props.onSubcatIconChange(newIcon)
            end)
          end,
        }),
      }),
    }),
  }

  if #formError > 0 then
    table.insert(cardChildren, ui.label({
      text = formError,
      fontSize = 11,
      color = "error",
    }))
  end

  table.insert(cardChildren, ui.row({
    justify = "end",
    gap = 8,
    align = "center",
  }, {
    ui.button({
      text = tr("modal.cancel"),
      variant = "ghost",
      onClick = function()
        props.onCancel()
      end,
    }),
    ui.button({
      text = tr("modal.save"),
      variant = "primary",
      onClick = function()
        local currentStore = props.getCustomStore()
        props.onSave(currentStore, editSubcatName, editSubcatIcon)
      end,
    }),
  }))

  return ui.column({
    flexGrow = 1,
    align = "center",
    justify = "center",
    padding = 16,
  }, {
    ui.column({
      width = 460,
      radius = 12 * cornerRadiusScale,
      fill = "surface",
      padding = 20,
      gap = 12,
      align = "stretch",
    }, cardChildren),
  })
end

function modals.renderAddEditKeybindModal(props: {
  modalMode: string, -- "create" or "edit"
  formApp: string,
  formAppIcon: string,
  formAppSelectedIdx: number,
  formSubcat: string,
  formSubcatIcon: string,
  formSubcatSelectedIdx: number,
  formDesc: string,
  formKey: string,
  formMods: { [string]: boolean },
  formError: string,
  cornerRadiusScale: number,
  tr: (string, any?) -> string,
  openIconPicker: (string, (string) -> ()) -> (),
  onAppSelected: (number) -> (),
  onAppChange: (string) -> (),
  onAppIconChange: (string) -> (),
  onSubcatSelected: (number) -> (),
  onSubcatChange: (string) -> (),
  onSubcatIconChange: (string) -> (),
  onDescChange: (string) -> (),
  onKeyChange: (string) -> (),
  onModToggle: (string) -> (),
  onCancel: () -> (),
  onSave: (currentStore: any, payload: any) -> (),
  getCustomStore: () -> any,
}): any
  local isEdit = (props.modalMode == "edit")
  local tr = props.tr
  local cornerRadiusScale = props.cornerRadiusScale or 1.0
  local modalTitle = if isEdit then tr("modal.title_edit") else tr("modal.title_add")

  local store = props.getCustomStore()
  local customApps = (type(store.apps) == "table") and store.apps or {}

  -- Build app options
  local appOptions = {}
  for _, a in ipairs(customApps) do
    table.insert(appOptions, a.name)
  end
  table.insert(appOptions, tr("modal.app_new_option"))

  local formAppSelectedIdx = props.formAppSelectedIdx
  if formAppSelectedIdx >= #appOptions then
    formAppSelectedIdx = 0
  end

  local isNewApp = (formAppSelectedIdx == #appOptions - 1)
  local chosenApp = if not isNewApp then customApps[formAppSelectedIdx + 1] else nil

  -- Build subcat options
  local subcatOptions = {}
  if chosenApp and type(chosenApp.subcategories) == "table" then
    for _, s in ipairs(chosenApp.subcategories) do
      table.insert(subcatOptions, s.name)
    end
  end
  table.insert(subcatOptions, tr("modal.subcat_new_option"))

  local formSubcatSelectedIdx = props.formSubcatSelectedIdx
  if formSubcatSelectedIdx >= #subcatOptions then
    formSubcatSelectedIdx = 0
  end

  local isNewSubcat = isNewApp or (formSubcatSelectedIdx == #subcatOptions - 1)
  local chosenSubcat = if not isNewSubcat and chosenApp and type(chosenApp.subcategories) == "table" then
    chosenApp.subcategories[formSubcatSelectedIdx + 1]
  else
    nil

  -- Modifier Chips
  local modButtons = {}
  local modNames = { "SUPER", "CTRL", "ALT", "SHIFT" }
  for _, m in ipairs(modNames) do
    local isSelected = (props.formMods[m] == true)
    table.insert(modButtons, ui.row({
      paddingV = 6,
      paddingH = 14,
      radius = 6 * cornerRadiusScale,
      fill = isSelected and "primary" or "surface_variant",
      onClick = function()
        props.onModToggle(m)
      end,
    }, {
      ui.label({
        text = m,
        fontSize = 11,
        fontWeight = "bold",
        color = isSelected and "on_primary" or "on_surface_variant",
      }),
    }))
  end

  -- App field
  local appHeaderChildren = {
    ui.label({ text = tr("modal.app_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
  }
  if not isNewApp and chosenApp then
    table.insert(appHeaderChildren, ui.row({ gap = 4, align = "center" }, {
      ui.glyph({ name = chosenApp.icon or "terminal", size = 12, color = "primary" }),
      ui.label({ text = chosenApp.icon or "terminal", fontSize = 10, color = "on_surface_variant" }),
    }))
  end

  local appFieldChildren = {
    ui.row({ justify = "space_between", align = "center" }, appHeaderChildren),
    ui.select({
      options = appOptions,
      selectedIndex = formAppSelectedIdx,
      onChange = function(idx)
        props.onAppSelected(tonumber(idx) or 0)
      end,
    }),
  }
  if isNewApp then
    table.insert(appFieldChildren, ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
      ui.input({
        key = "modal-app-input",
        placeholder = tr("modal.app_placeholder"),
        value = props.formApp,
        flexGrow = 1,
        onChange = function(val)
          props.onAppChange(val)
        end,
      }),
      ui.button({
        glyph = props.formAppIcon,
        variant = "secondary",
        tooltip = tr("modal.pick_icon"),
        onClick = function()
          props.openIconPicker(props.formAppIcon, function(newIcon)
            props.onAppIconChange(newIcon)
          end)
        end,
      }),
    }))
  end

  -- Subcategory field
  local subcatHeaderChildren = {
    ui.label({ text = tr("modal.subcat_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
  }
  if not isNewSubcat and chosenSubcat then
    table.insert(subcatHeaderChildren, ui.row({ gap = 4, align = "center" }, {
      ui.glyph({ name = chosenSubcat.icon or "command", size = 12, color = "primary" }),
      ui.label({ text = chosenSubcat.icon or "command", fontSize = 10, color = "on_surface_variant" }),
    }))
  end

  local subcatFieldChildren = {
    ui.row({ justify = "space_between", align = "center" }, subcatHeaderChildren),
  }
  if not isNewApp then
    table.insert(subcatFieldChildren, ui.select({
      options = subcatOptions,
      selectedIndex = formSubcatSelectedIdx,
      onChange = function(idx)
        props.onSubcatSelected(tonumber(idx) or 0)
      end,
    }))
  end
  if isNewSubcat then
    table.insert(subcatFieldChildren, ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
      ui.input({
        key = "modal-subcat-input",
        placeholder = tr("modal.subcat_placeholder"),
        value = props.formSubcat,
        flexGrow = 1,
        onChange = function(val)
          props.onSubcatChange(val)
        end,
      }),
      ui.button({
        glyph = props.formSubcatIcon,
        variant = "secondary",
        tooltip = tr("modal.pick_icon"),
        onClick = function()
          props.openIconPicker(props.formSubcatIcon, function(newIcon)
            props.onSubcatIconChange(newIcon)
          end)
        end,
      }),
    }))
  end

  local cardChildren = {
    -- Modal Header
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({
          name = isEdit and "pencil" or "plus",
          size = 16,
          color = "primary",
        }),
        ui.label({
          text = modalTitle,
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("modal.cancel"),
        onClick = function()
          props.onCancel()
        end,
      }),
    }),

    -- App Selection Field
    ui.column({ gap = 6, align = "stretch" }, appFieldChildren),

    -- Subcategory Selection Field
    ui.column({ gap = 6, align = "stretch" }, subcatFieldChildren),

    -- Description Field
    ui.column({ gap = 4, align = "stretch" }, {
      ui.label({ text = tr("modal.desc_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
      ui.input({
        key = "modal-desc-input",
        placeholder = tr("modal.desc_placeholder"),
        value = props.formDesc,
        onChange = function(val)
          props.onDescChange(val)
        end,
      }),
    }),

    -- Modifier Keys Row
    ui.column({ gap = 4, align = "stretch" }, {
      ui.label({ text = tr("modal.modifiers_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
      ui.row({ gap = 8, align = "center" }, modButtons),
    }),

    -- Primary Key Field
    ui.column({ gap = 4, align = "stretch" }, {
      ui.label({ text = tr("modal.key_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
      ui.input({
        key = "modal-key-input",
        placeholder = tr("modal.key_placeholder"),
        value = props.formKey,
        onChange = function(val)
          props.onKeyChange(string.upper(val))
        end,
      }),
    }),
  }

  if #props.formError > 0 then
    table.insert(cardChildren, ui.label({
      text = props.formError,
      fontSize = 11,
      color = "error",
    }))
  end

  table.insert(cardChildren, ui.row({
    justify = "end",
    gap = 8,
    align = "center",
  }, {
    ui.button({
      text = tr("modal.cancel"),
      variant = "ghost",
      onClick = function()
        props.onCancel()
      end,
    }),
    ui.button({
      text = tr("modal.save"),
      variant = "primary",
      onClick = function()
        local activeMods = {}
        if props.formMods.SUPER then table.insert(activeMods, "SUPER") end
        if props.formMods.CTRL then table.insert(activeMods, "CTRL") end
        if props.formMods.ALT then table.insert(activeMods, "ALT") end
        if props.formMods.SHIFT then table.insert(activeMods, "SHIFT") end

        local effectiveApp = if isNewApp then props.formApp else (appOptions[formAppSelectedIdx + 1] or props.formApp)
        local effectiveSubcat = if isNewSubcat then props.formSubcat else (subcatOptions[formSubcatSelectedIdx + 1] or props.formSubcat)

        local currentStore = props.getCustomStore()
        props.onSave(currentStore, {
          isNewApp = isNewApp,
          isNewSubcat = isNewSubcat,
          effectiveApp = effectiveApp,
          effectiveSubcat = effectiveSubcat,
          activeMods = activeMods,
        })
      end,
    }),
  }))

  return ui.column({
    flexGrow = 1,
    align = "center",
    justify = "center",
    padding = 16,
  }, {
    ui.column({
      width = 540,
      radius = 12 * cornerRadiusScale,
      fill = "surface",
      padding = 20,
      gap = 12,
      align = "stretch",
    }, cardChildren),
  })
end

return modals
