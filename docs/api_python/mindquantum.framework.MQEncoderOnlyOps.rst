.. py:class:: mindquantum.framework.MQEncoderOnlyOps(expectation_with_grad)

    MindQuantum 算子，通过参数化量子电路(PQC)获得对量子态的哈密顿期望。这个PQC应该只包含一个编码器电路。此操作仅受 `PYNATIVE_MODE` 支持。

    **参数：**

    - **expectation_with_grad** (GradOpsWrapper) – 接收encoder数据和ansatz数据，并返回期望值和参数相对于期望的梯度值。

    **输入：**

    - **enc_data** (Tensor) - 您希望编码为量子状态的Tensor，其shape为 :math:`(N, M)` ，其中 :math:`N` 表示batch大小， :math:`M` 表示encoder数量。

    **输出：**

    - **Output** (Tensor) - hamiltonian的期望值。
