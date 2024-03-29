.. py:class:: mindquantum.core.circuit.U3(theta, phi, lam, obj_qubit=None)

    该电路表示任意单量子比特门。

    U3门的矩阵为：

    .. math::

        U3(\theta, \phi, \lambda) =
        \begin{pmatrix}
           cos \left( \frac{\theta}{2} \right) & -e^{i \lambda} sin \left( \frac{\theta}{2} \\
        e^{i \phi} sin \left( \frac{\theta}{2} & e^{i (\phi + \lambda)} cos \left( \frac{\theta}{2}
        \end{pmatrix}

    它可以被分解为：

    .. math::

        U3(\theta, \phi, \lambda) = RZ(\phi) RX(-\pi/2) RZ(\theta) RX(\pi/2) RZ(\lambda)

    参数：
        - **theta** (Union[numbers.Number, dict, ParameterResolver]) - U3电路的第一个参数。
        - **phi** (Union[numbers.Number, dict, ParameterResolver]) - U3电路的第二个参数。
        - **lam** (Union[numbers.Number, dict, ParameterResolver]) - U3电路的第三个参数。
        - **obj_qubit** (int) - U3电路将作用于哪个量子比特上。默认值：None。
