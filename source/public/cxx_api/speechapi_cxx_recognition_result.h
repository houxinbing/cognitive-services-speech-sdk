//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//
// speechapi_cxx_recognition_result.h: Public API declarations for RecognitionResult C++ base class and related enum class
//

#pragma once
#include <string>
#include <speechapi_cxx_common.h>
#include <speechapi_cxx_enums.h>
#include <speechapi_cxx_properties.h>
#include <speechapi_c_result.h>


namespace Microsoft {
namespace CognitiveServices {
namespace Speech {


/// <summary>
/// Contains detailed information about result of a recognition operation.
/// </summary>
class RecognitionResult
{
private:

    class PrivatePropertyCollection : public PropertyCollection
    {
    public:
        PrivatePropertyCollection(SPXRESULTHANDLE hresult) : 
            PropertyCollection(
                [=]() {
                SPXPROPERTYBAGHANDLE hpropbag = SPXHANDLE_INVALID;
                result_get_property_bag(hresult, &hpropbag);
                return hpropbag;
            }())
        {
        }
    };

    PrivatePropertyCollection m_properties;

public:

    /// <summary>
    /// Virtual destructor.
    /// </summary>
    virtual ~RecognitionResult()
    {
        ::recognizer_result_handle_release(m_hresult);
        m_hresult = SPXHANDLE_INVALID;
    };

    /// <summary>
    /// Unique result id.
    /// </summary>
    const std::string& ResultId;

    /// <summary>
    /// Recognition reason.
    /// </summary>
    const Speech::ResultReason& Reason;

    /// <summary>
    /// Normalized text generated by a speech recognition engine from recognized input.
    /// </summary>
    const std::string& Text;

    /// <summary>
    /// Duration of the recognized speech.
    /// </summary>
    uint64_t Duration() const { return m_duration; }

    /// <summary>
    /// Offset of the recognized speech.
    /// </summary>
    uint64_t Offset() const { return m_offset; }

    /// <summary>
    /// Collection of additional RecognitionResult properties.
    /// </summary>
    PropertyCollection& Properties;

    /// <summary>
    /// Internal. Explicit conversion operator.
    /// </summary>
    explicit operator SPXRESULTHANDLE() { return m_hresult; }


protected:

    /*! \cond PROTECTED */

    explicit RecognitionResult(SPXRESULTHANDLE hresult) :
        m_properties(hresult),
        ResultId(m_resultId),
        Reason(m_reason),
        Text(m_text),
        Properties(m_properties),
        Handle(m_hresult),
        m_hresult(hresult)
    {
        PopulateResultFields(hresult, &m_resultId, &m_reason, &m_text);
    }

    const SPXRESULTHANDLE& Handle;

    /*! \endcond */

private:

    DISABLE_DEFAULT_CTORS(RecognitionResult); 

    void PopulateResultFields(SPXRESULTHANDLE hresult, std::string *resultId, Speech::ResultReason* reason, std::string* text)
    {

        SPX_INIT_HR(hr);

        const size_t maxCharCount = 1024;
        char sz[maxCharCount + 1];

        if (resultId != nullptr)
        {
            SPX_THROW_ON_FAIL(hr = result_get_result_id(hresult, sz, maxCharCount));
            *resultId = sz;
        }

        if (reason != nullptr)
        {
            Result_Reason resultReason;
            SPX_THROW_ON_FAIL(hr = result_get_reason(hresult, &resultReason));
            *reason = (Speech::ResultReason)resultReason;
        }

        if (text != nullptr)
        {
            SPX_THROW_ON_FAIL(hr = result_get_text(hresult, sz, maxCharCount));
            *text = sz;
        }

        SPX_THROW_ON_FAIL(hr = result_get_offset(hresult, &m_offset));
        SPX_THROW_ON_FAIL(hr = result_get_duration(hresult, &m_duration));
    }

    SPXRESULTHANDLE m_hresult;

    std::string m_resultId;
    Speech::ResultReason m_reason;
    std::string m_text;
    uint64_t m_offset;
    uint64_t m_duration;
};


/// <summary>
/// Contains detailed information about why a result was canceled.
/// </summary>
class CancellationDetails
{
private:

    CancellationReason m_reason;

public:

    /// <summary>
    /// Creates an instance of CancellationDetails object for the canceled RecognitionResult.
    /// </summary>
    /// <param name="result">The result that was canceled.</param>
    static std::shared_ptr<CancellationDetails> FromResult(std::shared_ptr<RecognitionResult> result)
    {
        // TODO VSTS 1407221
        // SPX_THROW_HR_IF(result->Reason != ResultReason::Canceled, SPXERR_INVALID_ARG);
        auto ptr = new CancellationDetails(result.get());
        auto cancellation = std::shared_ptr<CancellationDetails>(ptr);
        return cancellation;
    }

    /// <summary>
    /// The reason the result was canceled.
    /// </summary>
    const CancellationReason& Reason;

    /// <summary>
    /// In case of an unsuccessful recognition, provides a details of why the occurred error.
    /// This field is only filled-out if the reason canceled (<see cref="Reason"/>) is set to Error.
    /// </summary>
    const std::string ErrorDetails;

protected:

    /*! \cond PROTECTED */

    CancellationDetails(RecognitionResult* result) :
        m_reason(GetCancellationReason(result)),
        Reason(m_reason),
        ErrorDetails(result->Properties.GetProperty(PropertyId::SpeechServiceResponse_JsonErrorDetails))
    {
    }

    /*! \endcond */

private:

    DISABLE_DEFAULT_CTORS(CancellationDetails); 

    Speech::CancellationReason GetCancellationReason(RecognitionResult* result)
    {
        Result_CancellationReason reason;

        SPXRESULTHANDLE hresult = (SPXRESULTHANDLE)(*result);
        SPX_IFFAILED_THROW_HR(result_get_reason_canceled(hresult, &reason));

        return (Speech::CancellationReason)reason;
    }

};


/// <summary>
/// Contains detailed information for NoMatch recognition results.
/// </summary>
class NoMatchDetails
{
private:

    NoMatchReason m_reason;

public:

    /// <summary>
    /// Creates an instance of NoMatchDetails object for NoMatch RecognitionResults.
    /// </summary>
    /// <param name="result">The recognition result that was not recognized.</param>
    static std::shared_ptr<NoMatchDetails> FromResult(std::shared_ptr<RecognitionResult> result)
    {
        // TODO VSTS 1407221
        // SPX_IFTRUE_THROW_HR(result->Reason != ResultReason::NoMatch, SPXERR_INVALID_ARG);
        auto ptr = new NoMatchDetails(result.get());
        auto noMatch = std::shared_ptr<NoMatchDetails>(ptr);
        return noMatch;
    }

    /// <summary>
    /// The reason the result was not recognized.
    /// </summary>
    const NoMatchReason& Reason;

protected:

    /*! \cond PROTECTED */

    NoMatchDetails(RecognitionResult* result) :
        m_reason(GetNoMatchReason(result)),
        Reason(m_reason)
    {
    }

    /*! \endcond */

private:

    DISABLE_DEFAULT_CTORS(NoMatchDetails);

    Speech::NoMatchReason GetNoMatchReason(RecognitionResult* result)
    {
        Result_NoMatchReason reason;

        SPXRESULTHANDLE hresult = (SPXRESULTHANDLE)(*result);
        SPX_IFFAILED_THROW_HR(result_get_no_match_reason(hresult, &reason));

        return (Speech::NoMatchReason)reason;
    }

};

} } } // Microsoft::CognitiveServices::Speech
