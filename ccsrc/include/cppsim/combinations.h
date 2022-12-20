#ifndef COMBINATIONS_H
#define COMBINATIONS_H

#include "gpu_support.h"

#include <algorithm>
#include <array>
#include <cstdio>
#include <stdint.h>
#include <type_traits>

// Iterate through the combinations using currying approach: https://stackoverflow.com/a/54508163/4063520
class Combinations
{
// *****************************************************************************
// Simple case: no sum constraint
// *****************************************************************************
private :

	template<
		uint32_t n0, uint32_t n1, uint32_t ...n, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void _iterate(Callable&& c)
	{
		for (uint32_t i = 0; i < n0; i += 2 * n1)
		{
			auto bind_an_argument = [i, &c](auto... args)
			{
				c(i, args...);
			};

			_iterate<n1, n...>(bind_an_argument);
		}
	}

	template<
		uint32_t n0, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void _iterate(Callable&& c)
	{
		for (uint32_t i = 0; i < n0; i++)
		{
			c(i);
		}
	}


public :

	template<uint32_t ...n>
	struct Combination
	{
		using type = std::array<uint32_t, sizeof...(n)>;
	};

	// Iterate through all combinations.
	// For each combination, call a user-provided function.
	template<
		uint32_t ...n, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void iterate(Callable&& c)
	{
		_iterate<n...>(c);
	}

	// Tell the length of a combination supplied by the iterator
	// configured with the given set of template parameters.
	template<uint32_t ...n>
	static constexpr uint32_t length()
	{
		return sizeof...(n);
	}

	// Tell the number of combinations supplied by the iterator
	// configured with the given set of template parameters.
	template<uint32_t n0>
	static uint32_t _popcount()
	{
		return n0;
	}

	// Tell the number of combinations supplied by the iterator
	// configured with the given set of template parameters.
	template<uint32_t n0, uint32_t n1, uint32_t ...n>
	static uint32_t _popcount()
	{
		return (n0 / (2 * n1)) * _popcount<n1, n...>();
	}

	// Tell the number of combinations supplied by the iterator
	// configured with the given set of template parameters.
	template<uint32_t ...n>
	static uint32_t popcount()
	{
		if (sizeof...(n) == 0) return 0;
		return _popcount<n...>();
	}

	// Reverse the order of elements in a combination
	// configured with the given set of template parameters.	
	template<uint32_t ...n>
	static void reverse(typename Combination<n...>::type& c)
	{
		std::reverse(c.begin(), c.end());
	}

// *****************************************************************************
// Simple case: no sum constraint with a user-defined range
// *****************************************************************************
public :

	template<
		uint32_t n0, uint32_t n1, uint32_t ...n, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void _iterate(uint32_t* start, uint32_t& limit, Callable&& c)
	{
		for (uint32_t i = *start; (i < n0) && limit; i += 2 * n1)
		{
			// Flush starting point to zero, in order for all subsequent iterations
			// to start from zero as usual.
			*start = 0;

			auto bind_an_argument = [i, &c](auto... args)
			{
				c(i, args...);
			};

			_iterate<n1, n...>(start++, limit, bind_an_argument);
		}
	}

	template<
		uint32_t n0, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void _iterate(uint32_t* start, uint32_t& limit, Callable&& c)
	{
		for (uint32_t i = *start; (i < n0) && limit; i++)
		{
			// Flush starting point to zero, in order for all subsequent iterations
			// to start from zero as usual.
			*start = 0;

			c(i);
			limit--;
		}
	}

public :

	// Iterate through combinations with specific starting point and duration.
	// For each combination, call a user-provided function.
	template<
		uint32_t ...n, // max allowed sequence element value
		class Callable
	>
	GPU_SUPPORT
	static constexpr void iterate(const typename Combination<n...>::type& start_, const uint32_t limit_, Callable&& c)
	{
		auto start = start_;
		uint32_t limit = limit_;
		_iterate<n...>(start.data(), limit, c);
	}

	// Tell the number of combinations supplied by the iterator
	// configured with the given set of template parameters.
	template<uint32_t ...n>
	static uint32_t popcount(const uint32_t limit)
	{
		// XXX Actually could be less than limit, if start is closer to the end.
		return limit;
	}
};

#endif // COMBINATIONS_H

