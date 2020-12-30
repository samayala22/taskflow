#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include <doctest.h>
#include <taskflow/taskflow.hpp>
#include <taskflow/cudaflow.hpp>

#include "./details/graph_executor.hpp"
#include "./details/tree.hpp"
#include "./details/random_DAG.hpp"
#include "./details/tree.hpp"
#include "./details/diamond.hpp"

// ----------------------------------------------------------------------------
// Graph traversal
// ----------------------------------------------------------------------------
template <typename GRAPH, typename OPT, typename... OPT_Args>
void traversal(OPT_Args&&... args) {
  for(int i = 0; i < 13; ++i) {
    Graph* g;
    if constexpr(std::is_same_v<GRAPH, Tree>) {
      g = new Tree(::rand() % 3 + 1, ::rand() % 4 + 1);
    }
    else if constexpr(std::is_same_v<GRAPH, RandomDAG>) {
      g = new RandomDAG(::rand() % 7 + 1, ::rand() % 4 + 1, ::rand() % 3 + 1);
    }
    else if constexpr(std::is_same_v<GRAPH, Diamond>) {
      g = new Diamond(::rand() % 5 + 1, ::rand() % 4 + 1);
    }
    GraphExecutor<OPT> executor(*g, 0); 
    executor.traversal(std::forward<OPT_Args>(args)...);

    REQUIRE(g->traversed());
    delete g;
  }

}

TEST_CASE("cudaCapturer.tree.Sequential") {
  traversal<Tree,tf::SequentialOptimizer>();
}

TEST_CASE("cudaCapturer.tree.RoundRobin") {
  traversal<Tree, tf::RoundRobinOptimizer>(4);
}

TEST_CASE("cudaCapturer.tree.RoundRobin.2") {
  traversal<Tree, tf::RoundRobinOptimizer>(2);
}

TEST_CASE("cudaCapturer.tree.RoundRobin.3") {
  traversal<Tree, tf::RoundRobinOptimizer>(3);
}

TEST_CASE("cudaCapturer.tree.RoundRobin.4") {
  traversal<Tree, tf::RoundRobinOptimizer>(4);
}

TEST_CASE("cudaCapturer.randomDAG.Sequential") {
  traversal<RandomDAG,tf::SequentialOptimizer>();
}

TEST_CASE("cudaCapturer.randomDAG.RoundRobin.1") {
  traversal<RandomDAG, tf::RoundRobinOptimizer>(1);
}

TEST_CASE("cudaCapturer.randomDAG.RoundRobin.2") {
  traversal<RandomDAG, tf::RoundRobinOptimizer>(2);
}

TEST_CASE("cudaCapturer.randomDAG.RoundRobin.3") {
  traversal<RandomDAG, tf::RoundRobinOptimizer>(3);
}

TEST_CASE("cudaCapturer.randomDAG.RoundRobin.4") {
  traversal<RandomDAG, tf::RoundRobinOptimizer>(4);
}

TEST_CASE("cudaCapturer.diamond.Sequential") {
  traversal<Diamond,tf::SequentialOptimizer>();
}

TEST_CASE("cudaCapturer.diamond.RoundRobin.1") {
  traversal<Diamond, tf::RoundRobinOptimizer>(1);
}

TEST_CASE("cudaCapturer.diamond.RoundRobin.2") {
  traversal<Diamond, tf::RoundRobinOptimizer>(2);
}

TEST_CASE("cudaCapturer.diamond.RoundRobin.3") {
  traversal<Diamond, tf::RoundRobinOptimizer>(3);
}

TEST_CASE("cudaCapturer.diamond.RoundRobin.4") {
  traversal<Diamond, tf::RoundRobinOptimizer>(4);
}

//------------------------------------------------------
// dependencies
//------------------------------------------------------

template <typename OPT, typename... OPT_Args>
void dependencies(OPT_Args ...args) {
  
  for(int t = 0; t < 17; ++t) {
    int num_partitions = ::rand() % 5 + 1;
    int num_iterations = ::rand() % 7 + 1;

    Diamond g(num_partitions, num_iterations);

    tf::cudaFlowCapturer cf;
    cf.make_optimizer<OPT>(std::forward<OPT_Args>(args)...);

    int* inputs{nullptr};
    REQUIRE(cudaMallocManaged(&inputs, num_partitions * sizeof(int)) == cudaSuccess);
    REQUIRE(cudaMemset(inputs, 0, num_partitions * sizeof(int)) == cudaSuccess);

    std::vector<std::vector<tf::cudaTask>> tasks;
    tasks.resize(g.get_size());

    for(size_t l = 0; l < g.get_size(); ++l) {
      tasks[l].resize((g.get_graph())[l].size());
      for(size_t i = 0; i < (g.get_graph())[l].size(); ++i) {
        
        if(l % 2 == 1) {
          tasks[l][i] = cf.single_task([inputs, i] __device__ () {
            inputs[i]++;
          });
        }
        else {
          tasks[l][i] = cf.for_each(
            inputs, inputs + num_partitions, 
            [] __device__(int& v) { v *= 2; }
          );
        }
      }
    }

    for(size_t l = 0; l < g.get_size() - 1; ++l) {
      for(size_t i = 0; i < (g.get_graph())[l].size(); ++i) {
        for(auto&& out_node: g.at(l, i).out_nodes) {
          tasks[l][i].precede(tasks[l + 1][out_node]);
        }
      }
    }

    cf.offload();
    
    int result = 2;
    for(int i = 1; i < num_iterations; ++i) {
      result = result * 2 + 2;
    }

    for(int i = 0; i < num_partitions; ++i) {
      REQUIRE(inputs[i] == result);
    }

    REQUIRE(cudaFree(inputs) == cudaSuccess);
  }
}

TEST_CASE("cudaCapturer.dependencies.diamond.Sequential") {
  dependencies<tf::SequentialOptimizer>();
}

TEST_CASE("cudaCapturer.dependencies.diamond.RoundRobin.1") {
  dependencies<tf::RoundRobinOptimizer>(1);
}

TEST_CASE("cudaCapturer.dependencies.diamond.RoundRobin.2") {
  dependencies<tf::RoundRobinOptimizer>(2);
}

TEST_CASE("cudaCapturer.dependencies.diamond.RoundRobin.3") {
  dependencies<tf::RoundRobinOptimizer>(3);
}

TEST_CASE("cudaCapturer.dependencies.diamond.RoundRobin.4") {
  dependencies<tf::RoundRobinOptimizer>(4);
}
