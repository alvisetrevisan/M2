#include "supervisor.hpp"

#include <iostream>
#include <stdlib.h>
#include <assert.h>
const static int numThreads = 2;



extern "C" {
  THREADLOCALDECL(struct atomic_field, interrupts_interruptedFlag);
  THREADLOCALDECL(struct atomic_field, interrupts_exceptionFlag);
  struct ThreadSupervisor* threadSupervisor = 0 ;
  void initializeThreadSupervisor()
  {
    if(NULL==threadSupervisor)
      threadSupervisor = new ThreadSupervisor(numThreads);
    assert(threadSupervisor);
    threadSupervisor->m_TargetNumThreads=numThreads;
    threadSupervisor->initialize();
  }
  void pushTask(struct ThreadTask* task)
  {
    pthread_mutex_lock(&threadSupervisor->m_Mutex);
    if(task->m_Dependencies.empty())
      {
	threadSupervisor->m_ReadyTasks.push_back(task);
      }
    else
      {
	threadSupervisor->m_WaitingTasks.push_back(task);
      }
    pthread_cond_signal(&threadSupervisor->m_TaskWaitingCondition);
    pthread_mutex_unlock(&threadSupervisor->m_Mutex);
  }
  void addThreadBody(pthread_t thread, struct parse_ThreadCellBody_struct* body)
  {
  #ifdef GETSPECIFICTHREADLOCAL
    pthread_setspecific(threadSupervisor->m_ThreadSpecificKey,new void*[ThreadSupervisor::s_MaxThreadLocalIdCounter]);
  #endif
    pthread_mutex_lock(&threadSupervisor->m_Mutex);
    std::map<pthread_t, struct ThreadSupervisorInformation*>::iterator it = threadSupervisor->m_ThreadMap.find(thread);
    if(it==threadSupervisor->m_ThreadMap.end())
      {
	struct ThreadSupervisorInformation* tsi = new ThreadSupervisorInformation();
	tsi->m_ThreadId = thread;
	tsi->m_Body = body;
	threadSupervisor->m_ThreadMap[thread]=tsi;
      }
    else
      {
	it->second->m_Body=body;
      }
    pthread_mutex_unlock(&threadSupervisor->m_Mutex);
  }
  void addThread(pthread_t thread)
  {
#ifdef GETSPECIFICTHREADLOCAL
    pthread_setspecific(threadSupervisor->m_ThreadSpecificKey,new void*[ThreadSupervisor::s_MaxThreadLocalIdCounter]);
#endif
    pthread_mutex_lock(&threadSupervisor->m_Mutex);
    std::map<pthread_t, struct ThreadSupervisorInformation*>::iterator it = threadSupervisor->m_ThreadMap.find(thread);
    if(it==threadSupervisor->m_ThreadMap.end())
      {
	struct ThreadSupervisorInformation* tsi = new ThreadSupervisorInformation();
	tsi->m_ThreadId = thread;
	tsi->m_Body = NULL;
	threadSupervisor->m_ThreadMap[thread]=tsi;
      }
    pthread_mutex_unlock(&threadSupervisor->m_Mutex);
  }
  void delThread(pthread_t thread)
  {
    pthread_mutex_lock(&threadSupervisor->m_Mutex);
    std::map<pthread_t, struct ThreadSupervisorInformation*>::iterator it = threadSupervisor->m_ThreadMap.find(thread);
    if(it!=threadSupervisor->m_ThreadMap.end())
      {
	threadSupervisor->m_ThreadMap.erase(it);
      }
    pthread_mutex_unlock(&threadSupervisor->m_Mutex);
  }
  void addCancelTask(struct ThreadTask* task, struct ThreadTask* cancel)
  {
    pthread_mutex_lock(&task->m_Mutex);
    task->m_CancelTasks.insert(cancel);
    pthread_mutex_unlock(&task->m_Mutex);
  }
  void addStartTask(struct ThreadTask* task, struct ThreadTask* start)
  {
    pthread_mutex_lock(&task->m_Mutex);
    task->m_StartTasks.insert(start);
    pthread_mutex_unlock(&task->m_Mutex);
  }
  void addDependency(struct ThreadTask* task, struct ThreadTask* dependency)
  {
    pthread_mutex_lock(&dependency->m_Mutex);
    dependency->m_StartTasks.insert(task);
    pthread_mutex_unlock(&dependency->m_Mutex);
    pthread_mutex_lock(&task->m_Mutex);
    task->m_Dependencies.insert(dependency);
    pthread_mutex_unlock(&task->m_Mutex);
  }
  struct ThreadTask* createThreadTask(const char* name, ThreadTaskFunctionPtr func, void* userData, int timeLimitExists, time_t timeLimitSeconds)
  {
    return new ThreadTask(name,func,userData,(bool)timeLimitExists,timeLimitSeconds);
  }
  void* waitOnTask(struct ThreadTask* task)
  {
    return task->waitOn();
  }
  extern void TS_Add_ThreadLocal(int* refno, const char* name)
  {
    if(NULL == threadSupervisor)
      threadSupervisor = new ThreadSupervisor(numThreads);
    assert(threadSupervisor);
    int ref = threadSupervisor->m_ThreadLocalIdCounter++;
    if(ref>threadSupervisor->s_MaxThreadLocalIdCounter)
     abort();
    *refno = ref;
  }

};

ThreadTask::ThreadTask(const char* name, ThreadTaskFunctionPtr func, void* userData, bool timeLimit, time_t timeLimitSeconds):
  m_Name(name),m_Func(func),m_UserData(userData),m_Result(NULL),m_Done(false),m_Started(false),m_TimeLimit(timeLimit),m_Seconds(timeLimitSeconds),m_KeepRunning(true),m_CurrentThread(NULL)
{
  pthread_mutex_init(&m_Mutex,NULL);
  pthread_cond_init(&m_FinishCondition,NULL);
}
ThreadTask::~ThreadTask()
{
}
void* ThreadTask::waitOn()
{
  pthread_mutex_lock(&m_Mutex);
  if(!m_Done)
    pthread_cond_wait(&m_FinishCondition,&m_Mutex);
  void* ret = m_Result;
  pthread_mutex_unlock(&m_Mutex);
  return ret;
}

void staticThreadLocalInit()
{
  THREADLOCALINIT(interrupts_exceptionFlag);
  THREADLOCALINIT(interrupts_interruptedFlag);
}


ThreadSupervisor::ThreadSupervisor(int targetNumThreads):
  m_TargetNumThreads(targetNumThreads),m_ThreadLocalIdCounter(0)
{
  threadSupervisor=this;
  #ifdef GETSPECIFICTHREADLOCAL
  if(pthread_key_create(&m_ThreadSpecificKey,NULL))
    abort();
  pthread_setspecific(m_ThreadSpecificKey,new void*[s_MaxThreadLocalIdCounter]);
  #endif
  staticThreadLocalInit();
  pthread_cond_init(&m_TaskWaitingCondition,NULL);
  pthread_mutex_init(&m_Mutex,NULL);
}

ThreadSupervisor::~ThreadSupervisor()
{
  pthread_key_delete(m_ThreadSpecificKey);
}
void ThreadSupervisor::initialize()
{
  for(int i = 0; i < m_TargetNumThreads; ++i)
    {
      SupervisorThread* thread = new SupervisorThread();
      thread->start();
      m_Threads.push_back(thread);
    }
  extern int TS_Test();
  TS_Test();
}
void ThreadSupervisor::_i_finished(struct ThreadTask* task)
{
  pthread_mutex_lock(&m_Mutex);
  m_RunningTasks.remove(task);
  if(task->m_KeepRunning)
    {
      m_FinishedTasks.push_back(task);
    }
  else
    {
      m_CanceledTasks.push_back(task);
    }
  
  pthread_mutex_unlock(&m_Mutex);
}
void ThreadSupervisor::_i_startTask(struct ThreadTask* task, struct ThreadTask* launcher)
{
  pthread_mutex_lock(&m_Mutex);
  pthread_mutex_lock(&task->m_Mutex);
  if(!task->m_Dependencies.empty())
    {
      if(!launcher)
	{
	  pthread_mutex_unlock(&task->m_Mutex);
	  pthread_mutex_unlock(&m_Mutex);
	  return;
	}
      std::set<struct ThreadTask*>::iterator it = task->m_Dependencies.find(launcher);
      if(it!=task->m_Dependencies.end())
	{
	  task->m_Dependencies.erase(launcher);
	  task->m_FinishedDependencies.insert(launcher);
	}
      if(!task->m_Dependencies.empty())
	{
	  pthread_mutex_unlock(&task->m_Mutex);
	  pthread_mutex_unlock(&m_Mutex);
	  return;
	}
    }
  m_WaitingTasks.remove(task);
  m_ReadyTasks.push_back(task);
  pthread_cond_signal(&m_TaskWaitingCondition);
  pthread_mutex_unlock(&task->m_Mutex);
  pthread_mutex_unlock(&m_Mutex);
}
void ThreadSupervisor::_i_cancelTask(struct ThreadTask* task)
{
  std::cout << "canceling" << std::endl;
  pthread_mutex_lock(&m_Mutex);
  pthread_mutex_lock(&task->m_Mutex);
  AO_store(&task->m_CurrentThread->m_Interrupt->field,true);
  task->m_KeepRunning=false;
  std::cout << "ICT: " << task->m_CurrentThread->m_Interrupt << std::endl;
  std::cout << AO_load(&task->m_CurrentThread->m_Interrupt->field) << std::endl;
  std::cout << "set" << std::endl;
  pthread_mutex_unlock(&task->m_Mutex);
  pthread_mutex_unlock(&m_Mutex);
  std::cout << "out" << std::endl;
}
struct ThreadTask* ThreadSupervisor::getTask()
{
  pthread_mutex_lock(&m_Mutex);
  while(m_ReadyTasks.empty())
    {
      pthread_cond_wait(&m_TaskWaitingCondition,&m_Mutex);
    }
  struct ThreadTask* task = m_ReadyTasks.front();
  m_ReadyTasks.pop_front();
  m_RunningTasks.push_back(task);
  pthread_mutex_unlock(&m_Mutex);
  return task;
}
void ThreadTask::run(SupervisorThread* thread)
{
  pthread_mutex_lock(&m_Mutex);
  if(!m_KeepRunning)
    {
      threadSupervisor->_i_finished(this);
      pthread_mutex_unlock(&m_Mutex);
    }
  m_CurrentThread=thread;
  m_Started = true;
  pthread_mutex_unlock(&m_Mutex);
  m_Result = m_Func(m_UserData);
  pthread_mutex_lock(&m_Mutex);
  threadSupervisor->_i_finished(this);
  m_Done = true;
  m_CurrentThread=NULL;
  pthread_cond_broadcast(&m_FinishCondition);
  //cancel stuff
  for(std::set<ThreadTask*>::iterator it = m_CancelTasks.begin(); it!=m_CancelTasks.end(); ++it)
    threadSupervisor->_i_cancelTask(*it);
  //start stuff
  for(std::set<ThreadTask*>::iterator it = m_StartTasks.begin(); it!=m_StartTasks.end(); ++it)
    threadSupervisor->_i_startTask(*it,this);
  pthread_mutex_unlock(&m_Mutex);
}

SupervisorThread::SupervisorThread():m_KeepRunning(true)
{
  m_ThreadLocal = new void*[ThreadSupervisor::s_MaxThreadLocalIdCounter];
  m_Interrupt=&THREADLOCAL(interrupts_interruptedFlag,struct atomic_field);
}
void SupervisorThread::start()
{
  pthread_create(&m_ThreadId,NULL,SupervisorThread::threadEntryPoint,this);
}
void SupervisorThread::threadEntryPoint()
{
  #ifdef GETSPECIFICTHREADLOCAL
  pthread_setspecific(threadSupervisor->m_ThreadSpecificKey,m_ThreadLocal);
  #endif
  while(m_KeepRunning)
    {
      //AO_store(&m_Interrupt->field,false);
      struct ThreadTask* task = threadSupervisor->getTask();
      task->run(this);
    }
}
