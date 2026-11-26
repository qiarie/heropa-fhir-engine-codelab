/*
 * Copyright 2026 Open Health Stack Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package dev.ohs.fhir.codelab

import dev.ohs.fhir.engine.FhirEngine
import dev.ohs.fhir.engine.search.Order
import dev.ohs.fhir.engine.search.StringClientParam
import dev.ohs.fhir.engine.search.search
import dev.ohs.fhir.engine.sync.CurrentSyncJobStatus
import dev.ohs.fhir.model.r4.Patient
import dev.ohs.fhir.model.r4.QuestionnaireResponse
import dev.ohs.fhir.model.r4.Task
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
// 6 Imports for changing patient data
import dev.ohs.fhir.engine.search.StringFilterModifier
import dev.ohs.fhir.model.r4.String as FhirString
// 9 Imports for saving the patient
// 11 Imports for proposing tasks

/** The canonical URL of the plan definition that proposes tasks for a new patient. */
const val REGISTRATION_PLAN = "http://example.org/fhir/PlanDefinition/patient-registration"

class PatientListViewModel(
  private val fhirEngine: FhirEngine,
  private val syncLauncher: SyncLauncher,
  private val scope: CoroutineScope,
) {
  private val _pollState = MutableSharedFlow<CurrentSyncJobStatus>()
  val pollState: SharedFlow<CurrentSyncJobStatus> = _pollState

  private val _patients = MutableStateFlow<List<Patient>>(emptyList())
  val patients: StateFlow<List<Patient>> = _patients

  private val _tasks = MutableStateFlow<Map<String, List<Task>>>(emptyMap())

  /** The tasks of each patient, keyed by a patient reference such as `Patient/123`. */
  val tasks: StateFlow<Map<String, List<Task>>> = _tasks

  private val _message = MutableStateFlow<String?>(null)

  /** A message for the user, or null when there is none to show. */
  val message: StateFlow<String?> = _message

  /** The name typed in the search field. */
  var nameQuery = ""
    private set

  private var loadJob: Job? = null

  init {
    refreshPatients()
  }

  /**
   * Loads the patients from the local database, sorted by family name. Cancels the previous load,
   * so an older search can't replace the result of a newer one.
   */
  fun refreshPatients() {
    loadJob?.cancel()
    loadJob =
      scope.launch {
        _patients.value =
          fhirEngine
            .search<Patient> {
              sort(StringClientParam("family"), Order.ASCENDING)
              // 7 Filter the patients by name
              if (nameQuery.isNotEmpty()) {
                filter(
                  StringClientParam("name"),
                  {
                    modifier = StringFilterModifier.CONTAINS
                    value = nameQuery
                  },
                )
              }
            }
            .map { it.resource }
        _tasks.value =
          fhirEngine
            .search<Task> {}
            .map { it.resource }
            .groupBy { it.`for`?.reference?.value.orEmpty() }
      }
  }

  fun triggerOneTimeSync() {
    // 5.3 Start the sync
    scope.launch { syncLauncher.oneTimeSync().collect { _pollState.emit(it) } }
  }

  // 6.1 Search for patients by city
  private suspend fun searchByCity(city: String): List<Patient> =
    fhirEngine
      .search<Patient> {
        filter(
          StringClientParam("address-city"),
          {
            modifier = StringFilterModifier.MATCHES_EXACTLY
            value = city
          },
        )
      }
      .map { it.resource }

  // 6.2 Change the city of a patient
  private fun Patient.withCity(city: String): Patient =
    copy(
      address =
        address.mapIndexed { index, address ->
          if (index == 0) address.copy(city = FhirString(value = city)) else address
        },
    )

  /** Swaps the city of patients in Wakefield and Taunton, then syncs the changes. */
  fun triggerUpdate() {
    // 6.3 Update the patients and sync
    scope.launch {
      val patientsFromWakefield = searchByCity("Wakefield")
      val patientsFromTaunton = searchByCity("Taunton")

      patientsFromWakefield.forEach { fhirEngine.update(it.withCity("Taunton")) }
      patientsFromTaunton.forEach { fhirEngine.update(it.withCity("Wakefield")) }

      refreshPatients()
      triggerOneTimeSync()
    }
  }

  /** Saves the patient from the registration form, then proposes their first tasks. */
  fun registerPatient(questionnaireJson: String, questionnaireResponse: QuestionnaireResponse) {
    scope.launch {
      try {
        // 9 Replace with code from the codelab to extract and save the patient.

        // 11 Replace with code from the codelab to propose tasks for the patient.
      } catch (e: Exception) {
        _message.value = "Registration failed. ${e.message}"
      }
      refreshPatients()
    }
  }

  fun messageShown() {
    _message.value = null
  }

  /** Shows only the patients whose name contains [query], or all patients if it is empty. */
  fun searchPatientsByName(query: String) {
    nameQuery = query
    refreshPatients()
  }
}
