#include "task_handler.hpp"

#include "mqtt_communicator.hpp"
#include "logging.hpp"
#include "libvirt_hypervisor.hpp"
#include "parser.hpp"
#include "task.hpp"

#include <mosquittopp.h>

#include <string>
#include <exception>
#include <fstream>
#include <sstream>

Task_handler::Task_handler(const std::string &config_file) : 
	hypervisor(std::make_shared<Libvirt_hypervisor>()),
	running(true)
{
	std::ifstream file_stream(config_file);
	std::stringstream string_stream;
	string_stream << file_stream.rdbuf(); // Filestream to stingstream conversion
	comm = parser::str_to_communicator(string_stream.str());
}

Task_handler::~Task_handler()
{
	Thread_counter::wait_for_threads_to_finish();
}


void Task_handler::loop()
{
	while (running) {
		std::string msg;
		try {
			msg = comm->get_message();
			Task task;	
			task.from_string(msg);
			task.execute(hypervisor, comm);
		} catch (const YAML::Exception &e) {
			LOG_PRINT(LOG_ERR, "Exception while parsing message.");
			LOG_STREAM(LOG_ERR, e.what());
			LOG_STREAM(LOG_ERR, "msg dump: " << msg);
		} catch (const Task::no_task_exception &e) {
			LOG_PRINT(LOG_DEBUG, "Parsed message not being a Task.");
		} catch (const std::exception &e) {
			if (e.what() == std::string("quit")) {
				running = false;
				LOG_PRINT(LOG_DEBUG, "Quit msg received.");
			} else {
				LOG_STREAM(LOG_ERR, "Exception: " << e.what());
				LOG_STREAM(LOG_ERR, "msg dump: " << msg);
			}
		}
	}
}
