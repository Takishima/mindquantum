.. py:class:: mindquantum.core.gates.FSim(theta: ParameterResolver, phi: ParameterResolver)

    FSim 门表示费米子模拟门。FSim 门的矩阵形式为：

    .. math::

        {\rm FSim}(\theta, \phi)=\begin{pmatrix}1&0&0&0\\0&\cos(\theta)&-i\sin(\theta)&0\\
            0&-i\sin(\theta)&\cos(\theta)&0\\0&0&0&e^{i\phi}\end{pmatrix}

    参数：
        - **theta** (Union[numbers.Number, dict, ParameterResolver]) - FSim 门的第一个参数。
        - **phi** (Union[numbers.Number, dict, ParameterResolver]) - FSim 门的第二个参数。

    .. py:method:: get_cpp_obj()

        返回量子门的c++对象。

    .. py:method:: hermitian()

        获取 FSim 门的厄米共轭形式。

    .. py:method:: matrix(pr: ParameterResolver = None)

        获取 FSim 门的矩阵形式。

        参数：
            - **pr** (Union[ParameterResolver, dict]) - FSim 门的参数。默认值：None。

    .. py:method:: phi()

        获取 FSim 门的参数 phi。

        返回：
            ParameterResolver，参数 phi。

    .. py:method:: theta()

        获取 FSim 门的参数 theta。

        返回：
            ParameterResolver，参数 theta。
