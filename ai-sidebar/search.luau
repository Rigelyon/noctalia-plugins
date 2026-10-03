--!strict
local search = {}

export type SearchResultItem = {
  title: string,
  url: string,
  snippet: string,
}

export type SearchResponse = {
  ok: boolean,
  query: string,
  engine: string,
  items: { SearchResultItem },
  error: string?,
}

function search.formatSearchContext(items: { SearchResultItem }, query: string): string
  if #items == 0 then
    return ""
  end

  local lines = {
    string.format('[Web Search Results for: "%s"]', query),
  }
  for i, item in ipairs(items) do
    table.insert(lines, string.format("%d. [%s](%s)\n   %s", i, item.title, item.url, item.snippet))
  end
  table.insert(lines, "\nInstructions: Incorporate the above live web search information into your response. Cite sources with markdown links where appropriate.")
  return table.concat(lines, "\n")
end

function search.buildSearchRequest(engine: string, query: string, apiKey: string?, maxResults: number?): { url: string, method: string, headers: { string }?, body: string? }
  local limit = maxResults or 3
  local encQuery = noctalia.string.urlEncode(query)

  if engine == "tavily" then
    local bodyObj = {
      api_key = apiKey or "",
      query = query,
      max_results = limit,
      include_answer = true,
    }
    local encoded, _ = noctalia.json.encode(bodyObj)
    return {
      url = "https://api.tavily.com/search",
      method = "POST",
      headers = {
        "Content-Type: application/json",
      },
      body = encoded or "{}",
    }
  elseif engine == "brave" then
    return {
      url = string.format("https://api.search.brave.com/res/v1/web/search?q=%s&count=%d", encQuery, limit),
      method = "GET",
      headers = {
        "Accept: application/json",
        "X-Subscription-Token: " .. (apiKey or ""),
      },
    }
  else
    -- Default: DuckDuckGo instant answer API
    return {
      url = string.format("https://api.duckduckgo.com/?q=%s&format=json&no_html=1&skip_disambig=1", encQuery),
      method = "GET",
      headers = {
        "Accept: application/json",
      },
    }
  end
end

function search.parseSearchResponse(engine: string, body: string): { SearchResultItem }
  local items: { SearchResultItem } = {}
  local decoded, _ = noctalia.json.decode(body)
  if type(decoded) ~= "table" then
    return items
  end

  if engine == "tavily" then
    if type(decoded.results) == "table" then
      for _, r in ipairs(decoded.results) do
        if type(r) == "table" and type(r.title) == "string" and type(r.url) == "string" then
          table.insert(items, {
            title = r.title,
            url = r.url,
            snippet = type(r.content) == "string" and r.content or "",
          })
        end
      end
    end
  elseif engine == "brave" then
    if type(decoded.web) == "table" and type(decoded.web.results) == "table" then
      for _, r in ipairs(decoded.web.results) do
        if type(r) == "table" and type(r.title) == "string" and type(r.url) == "string" then
          table.insert(items, {
            title = r.title,
            url = r.url,
            snippet = type(r.description) == "string" and r.description or "",
          })
        end
      end
    end
  else
    -- DuckDuckGo
    if type(decoded.AbstractText) == "string" and decoded.AbstractText ~= "" then
      table.insert(items, {
        title = type(decoded.Heading) == "string" and decoded.Heading ~= "" and decoded.Heading or "DuckDuckGo Instant Answer",
        url = type(decoded.AbstractURL) == "string" and decoded.AbstractURL or "",
        snippet = decoded.AbstractText,
      })
    end
    if type(decoded.RelatedTopics) == "table" then
      for _, topic in ipairs(decoded.RelatedTopics) do
        if type(topic) == "table" and type(topic.Text) == "string" and type(topic.FirstURL) == "string" then
          local tTitle = topic.Text:match("^([^%-]+)%s*%-%s*") or topic.Text:sub(1, 40)
          table.insert(items, {
            title = noctalia.string.trim(tTitle),
            url = topic.FirstURL,
            snippet = topic.Text,
          })
        end
      end
    end
  end

  return items
end

function search.performSearch(query: string, config: any, callback: (ok: boolean, contextText: string?, err: string?) -> ()): ()
  local engine = (config and config.search_engine) or "duckduckgo"
  local apiKey = (config and config.search_api_key) or ""
  local maxResults = (config and tonumber(config.search_max_results)) or 3

  local req = search.buildSearchRequest(engine, query, apiKey, maxResults)

  noctalia.http(req :: any, function(resp)
    if not resp.ok or resp.status < 200 or resp.status >= 300 then
      callback(false, nil, "Search request failed with status " .. tostring(resp.status))
      return
    end

    local items = search.parseSearchResponse(engine, resp.body)
    if #items == 0 then
      callback(true, nil, nil)
    else
      local contextBlock = search.formatSearchContext(items, query)
      callback(true, contextBlock, nil)
    end
  end)
end

return search
