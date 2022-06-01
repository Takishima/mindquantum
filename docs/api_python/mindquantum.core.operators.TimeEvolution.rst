.. py:class:: mindquantum.core.operators.TimeEvolution(ops: mindquantum.core.operators.qubit_operator.QubitOperator, time=None)

    可以生成对应线路的时间进化算子。

    时间进化算子将执行以下进化：

    .. math::
        \left|\varphi(t)\right> = e^{-iHt}\left|\varphi(0)\right>

    .. note::
        哈密顿量应该是参数化或非参数化 `QubitOperator`。
        如果 `QubitOperator` 有多项，则将使用一阶Trotter分解。

    **参数：**

    - **ops** (QubitOperator) - 量子算子哈密顿量，可以参数化，也可以非参数化。
    - **time** (Union[numbers.Number, dict, ParameterResolver]) - 进化时间，可以是数字或参数解析器。如果是None，时间将设置为1。默认值：None。
