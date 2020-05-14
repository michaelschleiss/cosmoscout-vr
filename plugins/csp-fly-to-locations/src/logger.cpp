////////////////////////////////////////////////////////////////////////////////////////////////////
//                               This file is part of CosmoScout VR                               //
//      and may be used under the terms of the MIT license. See the LICENSE file for details.     //
//                        Copyright: (c) 2019 German Aerospace Center (DLR)                       //
////////////////////////////////////////////////////////////////////////////////////////////////////

#include "logger.hpp"

#include "../../../src/cs-utils/logger.hpp"

namespace csp::flytolocations {

////////////////////////////////////////////////////////////////////////////////////////////////////

spdlog::logger& logger() {
  static auto logger = cs::utils::createLogger("csp-fly-to-locations");
  return *logger;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

} // namespace csp::flytolocations
