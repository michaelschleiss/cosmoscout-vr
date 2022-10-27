////////////////////////////////////////////////////////////////////////////////////////////////////
//                               This file is part of CosmoScout VR                               //
////////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-FileCopyrightText: German Aerospace Center (DLR) <cosmoscout@dlr.de>
// SPDX-License-Identifier: MIT

#ifndef CSL_NODE_EDITOR_NODE_HPP
#define CSL_NODE_EDITOR_NODE_HPP

#include "csl_node_editor_export.hpp"

#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace csl::nodeeditor {

class NodeGraph;
class Connection;

class CSL_NODE_EDITOR_EXPORT Node {
 public:
  Node()          = default;
  virtual ~Node() = default;

  virtual void process(){};

  virtual void onMessage(std::string const& data){};

  void setID(uint32_t id);
  void setGraph(std::shared_ptr<NodeGraph> graph);

 protected:
  void sendMessage(std::string const& data) const;

  Connection const*              getInputConnection(std::string const& socket) const;
  std::vector<Connection const*> getOutputConnections(std::string const& socket) const;

 private:
  uint32_t                   mID;
  std::shared_ptr<NodeGraph> mGraph;
};

} // namespace csl::nodeeditor

#endif // CSL_NODE_EDITOR_NODE_HPP
