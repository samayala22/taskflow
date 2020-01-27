#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include <doctest.h>

#include <taskflow/taskflow.hpp>

// --------------------------------------------------------
// Testcase: BubbleSort
// --------------------------------------------------------
TEST_CASE("BubbleSort" * doctest::timeout(300)) {
  
  for(unsigned w=1; w<=9; w+=2) {

    tf::Executor executor(w);

    for(int end=10; end <= 1000; end += 100) {

      tf::Taskflow taskflow("BubbleSort");
      
      std::vector<int> data(end);

      for(auto& d : data) d = ::rand()%100;

      auto gold = data;
      std::sort(gold.begin(), gold.end());

      std::atomic<bool>swapped;

      // init task
      auto init = taskflow.emplace([&swapped](){ swapped = false; });
      auto cond = taskflow.emplace([&swapped](){
        if(swapped) {
          swapped = false;
          return 0;
        }
        return 1;
      });
      auto stop = taskflow.emplace([](){});

      auto even_phase = taskflow.emplace([&](tf::Subflow& sf){
        for(size_t i=0; i<data.size(); i+=2) {
          sf.emplace([&, i](){
            if(i+1 < data.size() && data[i] > data[i+1]) {
              std::swap(data[i], data[i+1]);
              swapped = true;
            }
          });
        }
      });

      auto odd_phase = taskflow.emplace([&](tf::Subflow& sf) {
        for(size_t i=1; i<data.size(); i+=2) {
          sf.emplace([&, i](){
            if(i+1 < data.size() && data[i] > data[i+1]) {
              std::swap(data[i], data[i+1]);
              swapped = true;
            }
          });
        }
      });

      init.precede(even_phase).name("init");
      even_phase.precede(odd_phase).name("even-swap");
      odd_phase.precede(cond).name("odd-swap");
      cond.precede(even_phase, stop).name("cond");

      executor.run(taskflow).wait();

      REQUIRE(gold == data);
    }
  }

}

// --------------------------------------------------------
// Testcase: MergeSort
// --------------------------------------------------------
TEST_CASE("MergeSort" * doctest::timeout(300)) {

  std::function<void(tf::Subflow& sf, std::vector<int>&, int, int)> spawn;

  spawn = [&] (tf::Subflow& sf, std::vector<int>& data, int beg, int end) mutable {

    if(!(beg < end) || end - beg == 1) {
      return;
    }

    if(beg - end <= 10) {
      std::sort(data.begin() + beg, data.begin() + end);
      return;
    }

    int m = (beg + end + 1) / 2;
    
    auto SL = sf.emplace([&spawn, &data, beg, m] (tf::Subflow& sf) {
      spawn(sf, data, beg, m);
    }).name(std::string("[") 
          + std::to_string(beg) 
          + ':' 
          + std::to_string(m) 
          + ')');

    auto SR = sf.emplace([&spawn, &data, m, end] (tf::Subflow& sf) {
      spawn(sf, data, m, end);
    }).name(std::string("[") 
          + std::to_string(m) 
          + ':' 
          + std::to_string(end) 
          + ')');

    auto SM = sf.emplace([&spawn, &data, beg, end, m] () {
      std::vector<int> tmpl, tmpr;
      for(int i=beg; i<m; ++i) tmpl.push_back(data[i]);
      for(int i=m; i<end; ++i) tmpr.push_back(data[i]);

      // merge to data
      size_t i=0, j=0, k=beg;
      while(i<tmpl.size() && j<tmpr.size()) {
        data[k++] = (tmpl[i] < tmpr[j] ? tmpl[i++] : tmpr[j++]);
      }

      // remaining SL
      for(; i<tmpl.size(); ++i) data[k++] = tmpl[i];
      
      // remaining SR
      for(; j<tmpr.size(); ++j) data[k++] = tmpr[j];
    }).name(std::string("merge [") 
          + std::to_string(beg) 
          + ':' 
          + std::to_string(end) + ')');

    SM.succeed(SL, SR);
  };

  for(unsigned w=1; w<=9; w+=2) {

    tf::Executor executor(w);

    for(int end=10; end <= 1000000; end = end * 10) {
      tf::Taskflow taskflow("MergeSort");
      
      std::vector<int> data(end);

      for(auto& d : data) d = ::rand()%100;

      auto gold = data;
      
      taskflow.emplace([&spawn, &data, end](tf::Subflow& sf){
        spawn(sf, data, 0, end);
      }).name(std::string("[0") 
            + ":" 
            + std::to_string(end) + ")");

      executor.run(taskflow).wait();

      std::sort(gold.begin(), gold.end());

      REQUIRE(gold == data);
    }
  }

}






