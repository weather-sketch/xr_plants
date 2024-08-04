using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class _Wobble : MonoBehaviour
{
    //public GameObject obj;
    public float duration = 2f;
    public float maxDegree = 30f;
    public float wobbleSpeed = 1f;
    Material mat;
    float time;

    Vector3 lastPos;
    Vector3 lastRot;
    // Start is called before the first frame update
    void Start()
    {
        mat = GetComponent<Renderer>().material;

        lastPos = transform.position;
        lastRot = transform.rotation.eulerAngles;
    }

    // Update is called once per frame
    void LateUpdate()
    {
        //lastPos = Vector3.Lerp(obj.transform.position, transform.position, Time.deltaTime / duration);
        //obj.transform.position = lastPos;

        Vector3 curPos = Vector3.Lerp(lastPos, transform.position, Time.deltaTime / duration);
        Vector3 curRot = Vector3.Lerp(lastRot, transform.rotation.eulerAngles, Time.deltaTime / duration);

        Vector3 velocity = transform.position - curPos;
        Vector3 angularVelocity = transform.rotation.eulerAngles - curRot;

        float x = Mathf.Clamp01(Mathf.Abs(velocity.z + angularVelocity.x));
        float z = Mathf.Clamp01(Mathf.Abs(velocity.x + angularVelocity.z));

        float wobbleX = x * Mathf.Sin(time) * maxDegree;
        float wobbleZ = z * Mathf.Sin(time) * maxDegree;

        mat.SetFloat("_WobbleX", wobbleX);
        mat.SetFloat("_WobbleZ", wobbleZ);

        lastPos = curPos;
        lastRot = curRot;
        time += Time.deltaTime * wobbleSpeed;
    }
}
