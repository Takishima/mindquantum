.. py:class:: mindquantum.core.gates.KrausChannel(name: str, kraus_op, **kwargs)

    用于表征量子计算中非相干噪声的量子信道。

    Kraus 信道接受两个或多个 2x2 矩阵作为 Kraus 算子，以在量子电路中构造自定义（单量子比特）噪声。

    Kraus 信道以如下形式作用噪声：

    .. math::

        \epsilon(\rho) = \sum_{k=0}^{m-1} E_k \rho E_k^\dagger

    其中 :math:`\rho` 是密度矩阵形式的量子态；:math:`E_k` 是Kraus算符，
    并且它需要满足完备性条件：:math:`\sum_k E_k^\dagger E_k = I`。

    参数：
        - **name** (str) - 该自定义噪声信道的名称。
        - **kraus_op** (list, np.ndarray) - Kraus 算符，由两个或多个 2x2 矩阵打包成的列表构成。

    .. py:method:: define_projectq_gate()

        定义对应的projectq门。

    .. py:method:: get_cpp_obj()

        获取底层c++对象。
