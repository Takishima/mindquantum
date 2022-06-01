.. py:class:: mindquantum.core.gates.ZZ(coeff=None)

    伊辛ZZ门。更多用法，请参见 :class:`mindquantum.core.gates.RX`。

    .. math::

        {\rm ZZ_\theta}=\cos(\theta)I\otimes I-i\sin(\theta)\sigma_Z\otimes\sigma_Z

    **参数：**
    - **coeff** (Union[int, float, str, dict, ParameterResolver]) - 参数化门的参数，详细解释请参见上文。默认值：None。
