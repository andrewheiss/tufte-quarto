-- Inject publication details and epigraphs before the TOC in PDF output.
-- Reads from 'publication-details' and 'epigraphs' YAML metadata keys.
-- Uses meta['include-before'], which Pandoc's LaTeX template places between
-- \maketitle and \tableofcontents.

if not quarto.doc.is_format("pdf") then
  return {}
end

-- Convert a metadata value to a LaTeX string for inline contexts
-- (e.g. inside \epigraph{}{}).
-- MetaInlines: rendered as a single line of LaTeX.
-- MetaBlocks:  paragraphs joined with \\ (hard line break).
local function meta_to_inline_latex(val)
  if val == nil then return "" end
  local t = pandoc.utils.type(val)
  if t == "Inlines" then
    local tex = pandoc.write(pandoc.Pandoc({ pandoc.Para(val) }), "latex")
    return (tex:gsub("^%s*(.-)%s*$", "%1"))
  elseif t == "Blocks" then
    local parts = {}
    for _, block in ipairs(val) do
      if block.t == "Para" or block.t == "Plain" then
        local tex = pandoc.write(
          pandoc.Pandoc({ pandoc.Para(block.content) }), "latex"
        )
        table.insert(parts, (tex:gsub("^%s*(.-)%s*$", "%1")))
      end
    end
    return table.concat(parts, "\\\\\n")
  end
  return pandoc.utils.stringify(val)
end

-- Convert a metadata value to a LaTeX string for block contexts
-- (e.g. a full copyright page). Preserves paragraph breaks.
local function meta_to_block_latex(val)
  if val == nil then return "" end
  local t = pandoc.utils.type(val)
  if t == "Inlines" then
    return pandoc.write(pandoc.Pandoc({ pandoc.Para(val) }), "latex")
  elseif t == "Blocks" then
    local blocks = {}
    for _, b in ipairs(val) do blocks[#blocks + 1] = b end
    return pandoc.write(pandoc.Pandoc(blocks), "latex")
  end
  return pandoc.utils.stringify(val)
end

function Pandoc(doc)
  local meta = doc.meta
  local before = ""

  -- Publication details page: content at bottom of page
  local pub = meta["publication-details"]
  if pub then
    before = before ..
      "\\thispagestyle{empty}\n" ..
      "\\vspace*{\\fill}\n" ..
      meta_to_block_latex(pub) ..
      "\\vspace*{\\fill}\n" ..
      "\\clearpage\n"
  end

  -- Epigraphs page
  if meta["epigraphs"] then
    local epi = "\\thispagestyle{empty}\n\\vspace*{\\fill}\n"
    for _, entry in ipairs(meta["epigraphs"] --[[@as pandoc.List]]) do
      local text_tex   = meta_to_inline_latex(entry["text"])
      local source_tex = meta_to_inline_latex(entry["source"])
      epi = epi ..
        "\\epigraph{" .. text_tex .. "}" ..
        "{\\upshape ---" .. source_tex .. "}\n"
    end
    before = before .. epi .. "\\vspace*{\\fill}\n\\clearpage\n"
  end

  if before ~= "" then
    doc.meta["include-before"] = pandoc.MetaBlocks({
      pandoc.RawBlock("latex", before)
    })
  end

  return doc
end
