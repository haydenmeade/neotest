local M = {}

---@param tree neotest.Tree
---@param line integer
---@return neotest.Tree
M.nearest = function(tree, line)
  local nearest = tree
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.range then
      if line >= pos.range[1] then
        nearest = node
      else
        return nearest
      end
    end
  end
  return nearest
end
---@param parent neotest.Position
---@param child neotest.Position
---@return boolean
M.contains = function(parent, child)
  if parent.type == "dir" then
    return parent.path == child.path
      or vim.startswith(child.path, parent.path .. require("neotest.lib.file").sep)
  end
  if child.type == "dir" then
    return false
  end
  if parent.type == "file" then
    return parent.path == child.path
  end
  if child.type == "file" then
    return false
  end
  return parent.range[1] <= child.range[1] and parent.range[3] >= child.range[3]
end

---@param tree neotest.Tree
---@param node neotest.Tree
local function replace_node(tree, node)
  local existing = tree:get_key(node:data().id)

  -- Find parent node and replace child reference
  local parent = existing:parent()
  if parent then
    for i, child in pairs(parent._children) do
      if node:data().id == child:data().id then
        parent._children[i] = node
        break
      end
    end
  end
  node._parent = parent

  -- Remove node and all descendants
  for _, pos in existing:iter() do
    tree._nodes[pos.id] = nil
  end

  -- Replace nodes map in new node and descendants
  for _, n in node:iter_nodes() do
    tree._nodes[n:data().id] = n
    n._nodes = tree._nodes
  end
end

---@param dir_tree neotest.Tree
---@param file_tree neotest.Tree
local function update_file_node(dir_tree, file_tree, force)
  local existing = dir_tree:get_key(file_tree:data().id)
  if not existing then
    error("File " .. file_tree:data().id .. " not in tree")
  end
  if force or (#existing:children() == 0 and #file_tree:children() > 0) then
    replace_node(dir_tree, file_tree)
  end
end

---@param orig neotest.Tree Directory tree
---@param new neotest.Tree File or directory tree
M.merge = function(orig, new)
  if not M.contains(orig:data(), new:data()) and not M.contains(new:data(), orig:data()) then
    error("Common root not found")
  end

  local new_type = new:data().type
  if new_type ~= "dir" and new_type ~= "file" then
    error("Can't merge " .. new_type .. " into tree")
  end

  if new:data().type == "file" then
    update_file_node(orig, new, true)
    return orig
  end

  if M.contains(new:data(), orig:data()) then
    for _, node in orig:iter_nodes() do
      if node:data().type == "file" and new:get_key(node:data().id) then
        update_file_node(new, node)
      end
    end

    return new
  end

  local existing_dir = orig:get_key(new:data().id)
  if existing_dir then
    for _, node in existing_dir:iter_nodes() do
      if node:data().type == "file" and new:get_key(node:data().id) then
        update_file_node(new, node)
      end
    end
  end
  replace_node(orig, new)
  return orig
end

return M
