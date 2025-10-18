好的，我们一起经历了非常真实且有价值的排错过程。将这些经验总结下来，对未来的学习和工作都非常有帮助。

这是一份为你整理的、关于到目前为止我们解决的所有问题的技术总结文档。

-----

### **ML基础设施项目CI/CD流水线排错总结**

**文档目的:** 本文档旨在记录在构建“ML模型服务平台”第一卷最终项目时，从环境配置到CI/CD自动化部署过程中遇到的关键技术问题、根本原因分析以及最终的解决方案。

-----

#### **问题1：端口冲突 (`address already in use`)**

  * **问题描述:** 在本地运行 `kubectl port-forward` 或其他需要监听端口的服务时，出现 `address already in use` 错误，提示端口（如8080）已被占用。但在WSL2内部使用 `lsof -i :8080` 却找不到任何占用进程。
  * **根本原因分析:** WSL2与Windows宿主机共享网络（尤其是`localhost`）。当一个Windows程序（如系统服务 `svchost.exe`）占用了某个端口，该端口在WSL2内部也会表现为被占用。Linux的 `lsof` 命令无法查看到Windows宿主机的进程。
  * **解决方案:**
    1.  **诊断 (Windows):** 在Windows的PowerShell（以管理员身份）中运行 `Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess` 来找到占用端口的Windows进程。
    2.  **规避:** 如果占用者是重要的系统进程（如`svchost.exe`），**不要**尝试终止它。最安全的做法是更换我们自己要使用的端口。例如，将命令修改为 `kubectl port-forward service/ml-api-service 8081:80`，使用本机的 `8081` 端口。
  * **核心知识点:** 理解WSL2与Windows宿主机的网络共享模型。排查端口问题时，需要同时考虑两个操作系统的环境。

-----

#### **问题2：`kind`集群外部无法访问 (Ingress不工作)**

  * **问题描述:** 在`kind`集群中部署了Ingress Controller和Ingress资源后，通过 `http://localhost` 无法访问服务。
  * **根本原因分析:** `kind`集群本身运行在一个Docker容器中。默认情况下，`kind`容器的80端口（HTTP）和443端口（HTTPS）并未映射到宿主机（你的电脑）的对应端口。如果宿主机的80端口在创建集群时已被占用，Docker会自动分配一个随机端口。
  * **解决方案:**
    1.  **删除旧集群:** `kind delete cluster --name <你的集群名>`
    2.  **创建配置文件 (`kind-config.yaml`):** 明确声明端口映射。
        ```yaml
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
        - role: control-plane
          extraPortMappings:
          - containerPort: 80
            hostPort: 80
          - containerPort: 443
            hostPort: 443
        ```
    3.  **使用配置创建新集群:** `kind create cluster --config kind-config.yaml --name <你的集群名>`
  * **核心知识点:** 本地Kubernetes开发工具（如`kind`）的网络模型依赖于其底层容器（Docker）的端口映射。必须在创建集群时就显式地规划好网络暴露。

-----

#### **问题3：CI流水线因代码格式问题失败**

  * **问题描述:** GitHub Actions流水线在`Code Formatting`步骤失败，提示 `Process completed with exit code 1`。
  * **根本原因分析:** 流水线中使用了 `black --check` 命令。该命令只检查代码格式是否符合规范，如果**不符合**，它会故意以非零退出码（表示失败）来中断流水线，强制开发者遵循代码风格。
  * **解决方案:** 在本地运行 `black <你的代码目录>`（不加`--check`）来自动格式化代码，然后将修改后的文件提交并推送。
  * **核心知识点:** CI（持续集成）的一个重要作用就是作为代码质量的“守门员”。格式检查失败是CI正常工作的表现。

-----

#### **问题4：CI中`pytest`找不到测试用例 (`collected 0 items`)**

  * **问题描述:** `pytest`命令在CI环境中运行时，报告 `collected 0 items`，没有执行任何测试。
  * **根本原因分析:** CI的运行环境和路径可能与本地不同，`pytest`的默认测试发现机制未能成功找到 `tests/` 目录下的文件。
  * **解决方案:** 在工作流文件中，明确告诉`pytest`去哪里寻找测试。将命令从 `run: pytest` 修改为 `run: pytest tests/`。
  * **核心知识点:** 在自动化脚本中，应始终使用明确的路径和参数，减少对环境隐式约定的依赖。

-----

#### **问题5：CI中测试因导入模块失败 (`ModuleNotFoundError`)**

  * **问题描述:** 运行`pytest tests/`时，测试文件中的 `from src.main import app` 失败，报告 `ModuleNotFoundError: No module named 'src'`。
  * **根本原因分析:** `pytest`从`tests/`目录启动时，Python的模块搜索路径中不包含项目的根目录，因此它找不到 `src` 这个模块。
  * **解决方案:** 在运行`pytest`之前，通过设置 `PYTHONPATH` 环境变量将项目根目录添加到搜索路径中。
    ```yaml
    - name: Run Unit & Integration Tests
      run: |
        export PYTHONPATH=.
        pytest tests/
    ```
  * **核心知识点:** `PYTHONPATH`是解决Python中相对导入问题的关键环境变量。

-----

#### **问题6：CI中`kubectl`验证YAML失败 (`connection refused`)**

  * **问题描述:** 在CI任务中运行 `kubectl apply --dry-run=client` 来验证Kubernetes YAML文件时，反复出现连接 `localhost:8080` 失败的错误。
  * **根本原因分析:** GitHub Actions的运行环境是一个没有Kubernetes集群的纯净虚拟机。`kubectl` 即使在客户端模式下，也可能尝试连接API服务器来获取验证所需的API规范（Schema），从而导致连接失败。
  * **解决方案:** 使用专为离线验证设计的工具 `kubeval`。
    ```yaml
    - name: Install kubeval
      run: |
        # 下载并安装 kubeval
        wget ...
        tar -xf ...
        sudo mv kubeval /usr/local/bin
    - name: Kubernetes Manifest Validation with kubeval
      run: kubeval --ignore-missing-schemas kubernetes/*.yaml
    ```
  * **核心知识点:** CI/CD环境是无状态且隔离的。应选择能在离线环境中工作的工具链，而不是依赖于一个活动的集群连接。

-----

#### **问题7：CI/CD自动化部署的系列网络与权限问题**

这是我们遇到的最复杂的问题，它包含多个层次：

  * **7a. 网络隔离:**

      * **问题:** 云端的GitHub Runner无法访问本地的`kind`集群。
      * **解决方案:** 使用**Self-hosted Runner**，将其安装在与`kind`集群处于同一网络环境的机器上（我们的WSL2）。

  * **7b. `kubeconfig`权限与配置:**

      * **问题:** Self-hosted Runner中的`kubectl`依然无法连接集群，反复报错`connection refused`。
      * **根本原因:**
        1.  **本地权限问题:** `~/.kube/config` 文件归属于`root`，导致普通用户身份运行的Runner无法读取。
        2.  **配置混淆:** CI环境（Docker网络内部）和本地环境（localhost）访问`kind`集群所需的`kubeconfig`是不同的。Runner错误地使用了指向`localhost`的配置。
      * **最终解决方案:**
        1.  修复本地权限：`sudo chown -R $USER:$USER ~/.kube`。
        2.  在Runner的工作流中，不再使用GitHub Secrets传递配置，而是直接使用一个预先放置在Runner环境中的、有效的`kubeconfig`文件，并通过 `KUBECONFIG` 环境变量强制`kubectl`使用它。

  * **7c. 镜像名称格式错误:**

      * **问题:** 部署卡在 `pending termination`，Pod事件显示 `InvalidImageName`。
      * **根本原因:**
        1.  **标签格式错误:** 工作流错误地将Git Commit SHA当作镜像摘要（digest）与`@`符号一起使用。
        2.  **大小写问题:** GitHub用户名包含大写字母，导致生成的镜像仓库名 `ghcr.io/YourName/repo` 不符合OCI镜像规范（必须小写）。
      * **最终解决方案:**
        1.  **传递摘要:** 在`build-and-push`任务中，将构建出的镜像摘要（digest）作为输出（output）。
        2.  **使用摘要:** 在`deploy`任务中，接收这个摘要，并使用 `image@sha256:...` 的格式来引用镜像，这是最精确、最不可变的方式。
        3.  **转为小写:** 在工作流中，使用shell命令 `echo ${{ github.repository }} | tr '[:upper:]' '[:lower:]'` 将仓库名强制转换为小写。

  * **核心知识点:**

      * CI/CD与基础设施的连接点（Runner）是网络和权限问题的多发地。
      * 自动化流程中的每一个标识符（如镜像名称）都必须精确无误。使用不可变标识（如`@digest`）比可变标识（如`:latest`）更可靠。
      * 严格遵守行业规范（如OCI镜像命名规范）。