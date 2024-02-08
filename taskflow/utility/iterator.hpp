#pragma once

#include <cstddef>
#include <type_traits>

namespace tf {

template <typename T>
constexpr bool is_range_invalid(T beg, T end) {
  return beg > end;
}

template <typename T>
constexpr std::enable_if_t<std::is_integral<std::decay_t<T>>::value, size_t>
distance(T beg, T end, T step) {
  return (end - beg + step + (step > 0 ? -1 : 1)) / step;
}

}  // end of namespace tf -----------------------------------------------------
