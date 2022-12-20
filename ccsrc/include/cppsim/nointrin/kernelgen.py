#!/usr/bin/env python3
import argparse
import itertools
import os

def kernelgen(nqubits, ids=None, m=None, matvec=True, combinations=False):
    # If m matrix is given explicitly, do not use matrix-vector form
    # of operation, because we expect many terms to be removed, due to
    # multiplication by zero m element.
    if not (m is None):
        matvec = False

    # All combinations of qubits, excluding dupes, e.g. for nqubits = 2:
    # 0 0
    # 1 0
    # 0 1
    # 1 1
    combs = list(itertools.product([0, 1], repeat=nqubits))

    # Pretty-print the indexed PSI array values.
    strcombs = []
    for j in range(0, len(combs)):
        comb = tuple(reversed(combs[j]))
        strcomb = 'psi[I'.format(j)
        for i in range(0, nqubits):
            if comb[i] != 0:
                strcomb += " + d{}".format(i)
        strcomb += ']';
        strcombs.append(strcomb)

    left = '_'
    right = ''
    if matvec:
        left = '['
        right = ']'

    # Pretty-print the right hand sides (recursively).
    if m is None:
        def rhs(n, j, i):
            if i < n - 1:
                return f'add(mul(v{left}{i}{right}, M({j}, {i})), ' + rhs(n, j, i + 1) + ''.join(')')
            else:
                return f'mul(v{left}{i}{right}, M({j}, {i})'
    else:
        def rhs(n, j, i):
            if i < n - 1:
                if m(j, i) != 0:
                    return f'add(mul(v{left}{i}{right}, M({j}, {i})), ' + rhs(n, j, i + 1) + ''.join(')')
                else:
                    return rhs(n, j, i + 1)
            else:
                if m(j, i) != 0:
                    return f'mul(v{left}{i}{right}, M({j}, {i})'
                else:
                    return '0'

    strrhs = [] 
    for j in range(0, len(strcombs)):
        strrhs.append(rhs(len(strcombs), j, 0))

    ids_sorted = []
    if ids != None:
        ids_sorted = sorted(ids, reverse = True)

    # Some string constants clash with the {} syntax of print(), so we
    # substitute them as constants.
    newline = "\n"

    kernel = \
"""
{include} <algorithm>
{include} <array>
{include} <complex>
{include} <cstdlib>
{eigen}
{combinations}

{define} add(a, b) (a + b)
{define} mul(a, b) (a * b)

{define} M(j, i) (m[j * {n} + i])

template<{d_template}class T>
inline void kernel_core(T* psi, std::size_t I{d_var}, const T* m)
{{
    {v}
    {matvec}
    {psi_assign}
}}

{undef} add
{undef} mul
{undef} M
""".format( \
        include    = "#include", \
        define     = "#define", \
        undef      = "#undef", \
        nqubits    = nqubits, \
        eigen      = "{define} EIGEN_DEFAULT_DENSE_INDEX_TYPE int{newline}{define} EIGEN_VECTORIZE{newline}{include} <Eigen/Dense>".format(define="#define", newline=newline, include = "#include") if matvec else '', \
        combinations = "#include \"combinations.h\"" if combinations else '', \
        n          = len(strcombs),
        d_template = ''.join('std::size_t d{}, '.format(i) for i in range (0, nqubits)) if ids != None else '', \
        d_var      = ''.join(', std::size_t d{}'.format(i) for i in range (0, nqubits)) if ids == None else '', \
        v          = f"const std::array v = {{{newline}" + ''.join('{}{},{}'.format(' ' * 8, strcombs[i], newline) for i in range(0, len(strcombs))) + "{}}};{}".format(' ' * 4, newline) if matvec else ''.join('const auto v_{} = {};{}{}'.format(i, strcombs[i], newline, ' ' * 4) for i in range(0, len(strcombs))), \
        matvec     = "const auto result = Eigen::Map<const Eigen::Matrix<T, {n}, {n}, Eigen::RowMajor>>(m) * Eigen::Map<const Eigen::Vector<T, {n}>>(v.data());{newline}".format(n = len(strcombs), newline = newline) if matvec else '', \
        psi_assign = ''.join('{} = {};{}    '.format(strcombs[i], strrhs[i], newline) for i in range(0, len(strcombs))) if not matvec else ''.join('{} = result[{}];{}    '.format(strcombs[i], i, newline) for i in range(0, len(strcombs)))) + \
"""
// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template<class T>
void kernel(T* psi, {id_var}const T* m, std::size_t ctrlmask)
{{
    {ids_sorted}
    {sort}
    {constexpr}std::size_t {n};
    {constexpr}std::size_t {d};
    {constexpr}std::size_t {dsorted};

    if (ctrlmask == 0){{
        {pragma} omp for collapse({collapse}) schedule(static)
        for (std::size_t i0 = 0; i0 < n; i0 += 2 * {dsorted_0}){{
{for_loops}{offset_2}for (std::size_t i{nqubits} = 0; i{nqubits} < {dsorted_last}; ++i{nqubits}){{
        {offset_1}kernel_core{d_template}(psi, {i}, {d_args}m);
        {offset}}}
        }}
    }}
    else{{
        {pragma} omp for collapse({collapse}) schedule(static)
        for (std::size_t i0 = 0; i0 < n; i0 += 2 * {dsorted_0}){{
{for_loops}{offset_2}for (std::size_t i{nqubits} = 0; i{nqubits} < {dsorted_last}; ++i{nqubits}){{
        {offset_1}if ((({i})&ctrlmask) == ctrlmask)
        {offset_2}kernel_core{d_template}(psi, {i}, {d_args}m);
        {offset}}}
        }}
    }}
}}

""".format( \
        pragma      = "#pragma", \
        nqubits     = nqubits, \
        id_var      = ''.join('unsigned id{}, '.format(nqubits - i - 1) for i in range (0, nqubits)) if ids == None else '', \
        constexpr   = 'constexpr ' if ids != None else '',
        d           = f"d0 = 1UL << {'id0' if ids == None else ids[0]}{''.join(', d{} = 1UL << {}'.format(i, 'id{}'.format(i) if ids == None else ids[i]) for i in range (1, nqubits))}", \
        d_args      = ''.join('d{}, '.format(i) for i in range (0, nqubits)) if ids == None else '', \
        n           = 'n = 1UL << (ids_sorted[0] + 1)' if ids == None else f'n = 1UL << {ids_sorted[0] + 1}', \
        ids_sorted  = (f"{'constexpr ' if ids != None else ''}std::size_t ids_sorted[] = {{ id{nqubits - 1}" + ''.join(', id{}'.format(nqubits - i - 1) for i in range (1, nqubits)) + f" }};") if ids == None else '', \
        sort        = f'std::sort(ids_sorted, ids_sorted + {nqubits}, std::greater<std::size_t>());' if ids == None else '', \
        dsorted     = f"dsorted0 = 1UL << {'ids_sorted[0]' if ids == None else ids_sorted[0]}{''.join(', dsorted{} = 1UL << {}'.format(i, 'ids_sorted[{}]'.format(i) if ids == None else ids_sorted[i]) for i in range (1, nqubits))}", \
        dsorted_0    = "dsorted0", \
        dsorted_last = f"dsorted{nqubits - 1}", \
        collapse    = f"{nqubits + 1}", \
        offset    = ''.join('    '.format(i) for i in range (0, nqubits)), \
        offset_1    = ''.join('    '.format(i) for i in range (0, nqubits + 1)), \
        offset_2    = ''.join('    '.format(i) for i in range (0, nqubits + 2)), \
        d_template  = ('<d0' + ''.join(', d{}'.format(i) for i in range (1, nqubits)) + '>') if ids != None else '', \
        i           = 'i0' + ''.join(' + i{}'.format(i) for i in range (1, nqubits + 1)), \
        for_loops   = ''.join('{}for (std::size_t i{} = 0; i{} < dsorted{}; i{} += 2 * dsorted{}){}'.format(''.join('    ' for j in range(0, i + 2)), i, i, i - 1, i, i, newline) for i in range (1, nqubits)))

    return kernel

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate Haener-Steiger quantum kernels in the form used in ProjectQ simulator')
    parser.add_argument('nqubits', type=int, help='the number of qubits to generate the kernel for')
    parser.add_argument('output', type=str, help='output file name')
    parser.add_argument('-matvec', '--matvec', nargs='?', type=bool, default=True, help='kernel core implementation: as a matrix-vector operation (True, default), or as an explicit formula (False)')
    parser.add_argument('-combinations', '--combinations', nargs='?', type=bool, default=True, help='multithreading implementation: combinations partitioner (True, default), or OpenMP collapse (False, only for CPU with small number of cores)')
    args = parser.parse_args()
    
    nqubits = int(args.nqubits)
    output = args.output
    matvec = args.matvec
    combinations = args.combinations

    try:
        os.makedirs(os.path.dirname(output))
    except:
        pass
    with open(output, "w") as o:
        o.write(kernelgen(nqubits, matvec=matvec, combinations=combinations))

