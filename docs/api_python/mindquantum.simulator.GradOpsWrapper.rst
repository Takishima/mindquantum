.. py:class:: mindquantum.simulator.GradOpsWrapper(grad_ops, hams, circ_right, circ_left, encoder_params_name, ansatz_params_name, parallel_worker)

    用生成梯度算子的信息包装梯度算子。

    **参数：**

    - **grad_ops** (Union[FunctionType, MethodType]) - 返回前向值和线路参数梯度的函数或方法。
    - **hams** (Hamiltonian) - 生成这个梯度算子的hamiltonian。
    - **circ_right** (Circuit) - 生成这个梯度算子的右电路。
    - **circ_left** (Circuit) - 生成这个梯度算子的左电路。
    - **encoder_params_name** (list[str]) - encoder参数名称。
    - **ansatz_params_name** (list[str]) - ansatz参数名称。
    - **parallel_worker** (int) - 运行批处理的并行工作器数量。
